import threading
import tkinter as tk
import pyautogui
import ctypes
from pynput import mouse

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
    root = tk.Tk()
    root.overrideredirect(True)
    root.attributes("-topmost", True)
    x, y = pyautogui.position()
    x += 20
    y += 20
    root.geometry(f"+{x}+{y}")
    label = tk.Label(root, text=text, bg="yellow", fg="black", padx=10, pady=5)
    label.pack()
    root.after(1000, root.destroy)
    root.mainloop()

def disable_slow_mode():
    global slow_mode
    slow_mode = False
    set_mouse_speed(original_speed)
    print("Режим замедления мыши отключен.")
    threading.Thread(target=show_notification, args=("Замедление выключено",), daemon=True).start()

def toggle_slow_mode():
    global slow_mode, timer
    if slow_mode:
        disable_slow_mode()
    else:
        slow_mode = True
        set_mouse_speed(max(1, original_speed // slow_factor))
        print("Режим замедления мыши включен.")
        threading.Thread(target=show_notification, args=("Замедление включено",), daemon=True).start()
        if timer:
            timer.cancel()
        timer = threading.Timer(5, disable_slow_mode)
        timer.start()

def on_click(x, y, button, pressed):
    if button == mouse.Button.right and pressed:
        toggle_slow_mode()
        return False  # Прекращаем обработку этого события

listener = mouse.Listener(on_click=on_click)
listener.start()

print("Программа запущена. Нажмите правую кнопку мыши для замедления.")

listener.join()
