# Mouse Slowdown Toggle with AppsKey

This Python script allows you to **temporarily slow down your mouse movement** by pressing the `AppsKey` (context menu key) on your keyboard.  
- The mouse speed is reduced to 1/10 of the original speed.
- A small **notification** appears near the cursor when slow mode is activated or deactivated.
- The slowdown turns off automatically after 5 seconds or when `AppsKey` is pressed again.

## Features
- Toggle slowdown mode with `AppsKey`.
- Mouse speed reduced by 10x.
- Notification shown near the cursor for 1 second.
- Automatic deactivation after 5 seconds.

## Requirements
- Python 3.7+
- `pyautogui`, `keyboard`

Install dependencies:
```bash
pip install pyautogui keyboard
