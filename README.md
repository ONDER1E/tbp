# Battery PD Bypass Monitor (Termux + Shizuku)

A lightweight shell script that monitors Android battery level and automatically toggles **USB PD battery bypass (pass-through) mode** using **Shizuku**.

This is intended for devices that support bypass charging (a.k.a. pause USB Power Delivery), allowing the phone to draw power directly from the charger instead of cycling the battery — useful for gaming, Dex, long sessions, or thermal control.

## Features

- Battery level monitoring with up to **10 retry attempts**
- Shizuku-based control via:
    - settings get system pass_through
    - settings put system pass_through <0|1>
- Only updates pass-through state **if it actually needs changing**
- Automatic fallback if battery reads fail
- Verbose logging for debugging
- Configurable thresholds
- Designed for Termux environments

## How It Works

Each loop cycle:

1. Reads battery percentage using `dumpsys battery`
2. Determines expected bypass state:
 - Enable if `>= ENABLE_THRESHOLD`
 - Disable if `<= DISABLE_THRESHOLD`
3. Reads current `pass_through` state (with retries)
4. Only applies `settings put system pass_through` if different
5. Logs everything

## Requirements

- Android device
- Termux
- Shizuku (running and authorized)
- USB-PD charger (PPS recommended for most devices)
- Device that supports bypass charging

## Installation/Usage

```bash
git clone https://github.com/ONDER1E/tbp.git
cd tbp
chmod +x tbp.sh
./tbp.sh
```

## Debugging

Logs will be written to:

```
tbp/monitor.log
```

---

## Device Compatibility

⚠️ **Important:**
This script only works on devices that expose a working:

```
settings put system pass_through
```

Not all Android devices support this.

Bypass charging is an OEM-specific feature. There is **no universal Android standard** for it.

## Known Device Families With Bypass Charging Support

Support depends on software version and charger capability (USB-PD with PPS is often required).
Some device brands may imlpement their own service to control USB PD battery bypass already, e.g: Samsung GOC which may interfere with the bypass state, disabiling such services is ideal however may remove some safety features such as thermal protection.

### Samsung (Pause USB Power Delivery)

Typically available inside Game Booster / Game Launcher.

Examples include:

* Galaxy S25-S21 series
* Galaxy Z Fold 4 / 5
* Galaxy Z Flip 4 / 5
* Galaxy A33 / A53 / A73
* Galaxy Tab S8 series

Behavior varies by One UI version.

### ASUS

Available on gaming-focused models via Game Genie.

Examples:

* ROG Phone 3+
* ROG Phone 5 series
* ROG Phone 6 series
* ROG Phone 7 series
* Some Zenfone models

### Sony

Available via Game Enhancer on supported Xperia models.

### Other Gaming Phones

Some devices from:

* RedMagic
* Black Shark

## Important Notes

* Some OEMs only enable bypass while gaming.
* Some devices hide the setting unless a compatible PD/PPS charger is connected.
* Some devices may expose the setting but ignore writes.
* If `settings get system pass_through` fails, the script assumes the expected state and writes it.
* If Shizuku is not running, commands will fail.

## Example Log Output

```
2026-02-20 06:24:21 | Battery=49%
2026-02-20 06:24:21 | pass_through already 1 — no change
```

Verbose mode shows every retry attempt and raw read values.

## Safety Disclaimer

This script modifies system settings.
Use at your own risk.

Improper charger setups or unsupported devices may cause unexpected behavior.