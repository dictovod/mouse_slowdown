import threading
import tkinter as tk
import pyautogui
import ctypes
import keyboard

slow_mode = False
slow_factor = 10
timer = None

SPI_GETMOUSESPEED = 0x0070
SPI_SETMOUSESPEED = 0x0071
SystemParametersInfo = ctypes.windll.user32.SystemParametersInfoW

def get_mouse_speed():
    speed = ctypes.c_int()
    SystemParametersInfo(SPI_GETMOUSESPEED, 0, ctypes.byref(speed), 0)
    return speed.value

def set_mouse_speed(speed):
    SystemParametersInfo(SPI_SETMOUSESPEED, 0, speed, 0)

original_speed = get_mouse_speed()

def show_notification(text):
    # Создаем всплывающее окно с привязкой к позиции курсора
    root = tk.Tk()
    root.overrideredirect(True)
    root.attributes("-topmost", True)
    x, y = pyautogui.position()
    x += 20
    y += 20
    root.geometry(f"+{x}+{y}")
    label = tk.Label(root, text=text, bg="yellow", fg="black", padx=10, pady=5)
    label.pack()
    # Закрываем окно через 1 секунду
    root.after(1000, root.destroy)
    root.mainloop()

def disable_slow_mode():
    global slow_mode
    slow_mode = False
    set_mouse_speed(original_speed)
    print("Режим замедления мыши отключен.")
    threading.Thread(target=show_notification, args=("Off",), daemon=True).start()

def toggle_slow_mode():
    global slow_mode, timer
    if slow_mode:
        disable_slow_mode()
    else:
        slow_mode = True
        set_mouse_speed(max(1, original_speed // slow_factor))
        print("Режим замедления мыши включен.")
        threading.Thread(target=show_notification, args=("On",), daemon=True).start()
        if timer:
            timer.cancel()
        timer = threading.Timer(5, disable_slow_mode)
        timer.start()

def on_key_event(event):
    if event.event_type == 'down' and event.scan_code == 93:
        toggle_slow_mode()
        return False

keyboard.hook(on_key_event)

print("Программа запущена. Нажмите AppsKey для замедления мыши.")

keyboard.wait()
