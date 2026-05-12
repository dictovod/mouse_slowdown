$ErrorActionPreference = "Stop"

if (!(Test-Path "Cargo.toml")) { cargo init --name mouse_tool }

$toml = @"
[package]
name = "mouse_tool"
version = "0.1.0"
edition = "2021"

[dependencies]
windows-sys = { version = "0.52.0", features = [
    "Win32_Foundation",
    "Win32_UI_WindowsAndMessaging",
    "Win32_UI_Input",
    "Win32_UI_Input_KeyboardAndMouse",
    "Win32_System_LibraryLoader",
    "Win32_Graphics_Gdi"
] }
"@
$toml | Out-File -FilePath "Cargo.toml" -Encoding ascii

$rust = @'
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::{SystemTime, UNIX_EPOCH};
use std::{mem::size_of, ptr::null_mut};
use windows_sys::Win32::Foundation::{HWND, LPARAM, LRESULT, WPARAM};
use windows_sys::Win32::System::LibraryLoader::GetModuleHandleW;
use windows_sys::Win32::UI::Input::KeyboardAndMouse::{VK_VOLUME_DOWN, VK_VOLUME_UP};
use windows_sys::Win32::UI::Input::{
    GetRawInputData, RegisterRawInputDevices, HRAWINPUT, RAWINPUT, RAWINPUTDEVICE,
    RAWINPUTHEADER, RIDEV_INPUTSINK, RID_INPUT, RIM_TYPEKEYBOARD, RIM_TYPEHID,
};
use windows_sys::Win32::UI::WindowsAndMessaging::{
    CreateWindowExW, DefWindowProcW, DispatchMessageW, GetMessageW, RegisterClassW,
    SystemParametersInfoW, TranslateMessage, MSG, SPIF_SENDCHANGE, SPIF_UPDATEINIFILE,
    SPI_GETMOUSESPEED, SPI_SETMOUSESPEED, WNDCLASSW, WM_INPUT,
};

static LAST: AtomicU64 = AtomicU64::new(0);
static ACTIVE: AtomicU64 = AtomicU64::new(0);

fn now_ms() -> u64 {
    SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_millis() as u64
}

unsafe extern "system" fn wndproc(hwnd: HWND, msg: u32, w: WPARAM, l: LPARAM) -> LRESULT {
    if msg == WM_INPUT {
        let mut size: u32 = 0;
        GetRawInputData(l as HRAWINPUT, RID_INPUT, null_mut(), &mut size, size_of::<RAWINPUTHEADER>() as u32);

        if size > 0 {
            let mut buf = vec![0u8; size as usize];
            if GetRawInputData(l as HRAWINPUT, RID_INPUT, buf.as_mut_ptr() as *mut _, &mut size, size_of::<RAWINPUTHEADER>() as u32) == size {
                let raw = &*(buf.as_ptr() as *const RAWINPUT);

                match raw.header.dwType {
                    RIM_TYPEKEYBOARD => {
                        let kb = raw.data.keyboard;
                        let is_keydown = (kb.Flags & 1) == 0;
                        if is_keydown {
                            println!("RAW KEYBOARD: VK={}", kb.VKey);
                            let v_up = VK_VOLUME_UP as u16;
                            let v_down = VK_VOLUME_DOWN as u16;
                            if kb.VKey == v_up || kb.VKey == v_down {
                                adjust_speed(kb.VKey);
                            }
                        }
                    }
                    RIM_TYPEHID => {
                        let hid = raw.data.hid;
                        if hid.dwSizeHid > 0 {
                            let report = &buf[hid.dwSizeHid as usize..];
                            if !report.is_empty() {
                                let usage = report[0];
                                println!("RAW HID (Consumer): usage={}", usage);
                                if usage == 0xE9 {
                                    adjust_speed(VK_VOLUME_DOWN as u16);
                                } else if usage == 0xEA {
                                    adjust_speed(VK_VOLUME_UP as u16);
                                }
                            }
                        }
                    }
                    _ => {}
                }
            }
        }
        return 0;
    }
    DefWindowProcW(hwnd, msg, w, l)
}

unsafe fn adjust_speed(vkey: u16) {
    let ms = now_ms();
    let active_until = ACTIVE.load(Ordering::SeqCst);

    if ms < active_until {
        let mut s: u32 = 0;
        SystemParametersInfoW(SPI_GETMOUSESPEED, 0, &mut s as *mut _ as *mut _, 0);

        if vkey == VK_VOLUME_UP as u16 && s < 20 {
            s += 1;
        } else if vkey == VK_VOLUME_DOWN as u16 && s > 1 {
            s -= 1;
        }

        SystemParametersInfoW(SPI_SETMOUSESPEED, 0, s as *mut _, SPIF_UPDATEINIFILE | SPIF_SENDCHANGE);
        ACTIVE.store(ms + 2000, Ordering::SeqCst);
        println!("[ACTIVE MODE] Speed set to: {}", s);
    } else {
        let last_press = LAST.load(Ordering::SeqCst);
        if ms - last_press < 500 {
            println!("*** DOUBLE TAP DETECTED! ADJUSTMENT ENABLED (2s) ***");
            ACTIVE.store(ms + 2000, Ordering::SeqCst);
        } else {
            println!("-> First tap (tap again within 500ms)");
        }
    }
    LAST.store(ms, Ordering::SeqCst);
}

fn main() {
    println!("=== MOUSE SPEED TOOL (RAW INPUT) STARTED ===");
    println!("Listening for volume keys (keyboard + consumer page)...");
    unsafe {
        let h_inst = GetModuleHandleW(null_mut());
        let class_name: Vec<u16> = "RawInputWindow\0".encode_utf16().collect();

        let wc = WNDCLASSW {
            lpfnWndProc: Some(wndproc),
            hInstance: h_inst,
            lpszClassName: class_name.as_ptr(),
            ..std::mem::zeroed()
        };
        RegisterClassW(&wc);

        let hwnd = CreateWindowExW(
            0, class_name.as_ptr(), null_mut(), 0, 0, 0, 0, 0,
            0, 0, h_inst, null_mut()
        );

        // Регистрируем два устройства: Keyboard (1/6) и Consumer Control (0x0C/0x01)
        let mut rids = [
            RAWINPUTDEVICE {
                usUsagePage: 0x01,
                usUsage: 0x06,
                dwFlags: RIDEV_INPUTSINK,
                hwndTarget: hwnd,
            },
            RAWINPUTDEVICE {
                usUsagePage: 0x0C,
                usUsage: 0x01,
                dwFlags: RIDEV_INPUTSINK,
                hwndTarget: hwnd,
            },
        ];

        let res = RegisterRawInputDevices(rids.as_mut_ptr(), rids.len() as u32, size_of::<RAWINPUTDEVICE>() as u32);
        if res == 0 {
            eprintln!("RegisterRawInputDevices failed!");
            return;
        }

        println!("Raw input registered successfully.");

        let mut msg: MSG = std::mem::zeroed();
        while GetMessageW(&mut msg, 0, 0, 0) > 0 {
            TranslateMessage(&msg);
            DispatchMessageW(&msg);
        }
    }
}
'@
$rust | Out-File -FilePath "src/main.rs" -Encoding ascii

Write-Host "Компиляция..." -ForegroundColor Cyan
cargo build --release

Write-Host "Запуск (Ctrl+C для выхода)..." -ForegroundColor Yellow
cargo run --release