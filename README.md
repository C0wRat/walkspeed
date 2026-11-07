# WalkSpeed

An iPhone app that stops you from walking too fast. Set a speed limit, tap
**Start** and put your phone in your pocket. WalkSpeed keeps measuring your
speed in the background and beeps over your music whenever you walk faster
than your limit.

## Features

- **Live speed** on a ring gauge with a notch at your limit, in km/h or mph.
- **Alerts that say how much to slow down.** One beep means you're just over
  your limit, two means clearly over and three means well over. Each pattern
  is pitched higher than the one before.
- **Plays nicely with music.** Beeps mix with whatever is playing and lower
  its volume for a moment. They play through headphones when you have them
  in, and they ignore the silent switch.
- **Runs in the background** with the phone locked. It only needs location
  permission while the app is in use; iOS shows a blue location indicator
  while WalkSpeed is monitoring.
- **Works indoors too.** When GPS is weak or missing, the iPhone's pedometer
  takes over. When both are available, they're combined.
- **No false alarms from GPS noise.** Speeds are smoothed, the first beep waits
  until you've been over the limit for a moment, and alerts pause at vehicle
  speeds.
- **Session totals:** time, top speed, time over the limit and number of
  alerts.

## How it works

1. Core Location reports your speed about once a second. While you walk,
   the pedometer in the motion coprocessor reports your pace every few
   seconds.
2. `SpeedSmoother` takes the median of the last four seconds of GPS readings
   and skips readings with poor accuracy. `SpeedEstimator` then blends that
   with the pedometer, weighting each by the inverse of its variance: strong
   GPS dominates, weak GPS defers to the pedometer, and either carries on
   alone when the other drops out.
3. `OverspeedDetector` starts an alert once the smoothed speed has been over
   the limit for the alert delay (2 seconds by default). It repeats every
   repeat interval (5 seconds by default) until you slow down. A small
   hysteresis band stops it flapping when you hover right at the limit.
4. `BeepPlayer` activates a mixable audio session only while a beep plays.
   Other audio ducks just for the beep.

The logic lives in [`WalkSpeedCore`](Packages/WalkSpeedCore), a Swift package
with no iOS dependencies and its own tests. The app target adds Core Location,
audio and the SwiftUI interface on top.

## Requirements

- An iPhone running iOS 17 or later.
- Xcode 16 or later. The project uses synchronized folders, and it was
  developed with Xcode 27.2.
- An Apple ID signed in to Xcode, to install on a device. A free account works,
  but apps it installs stop launching after 7 days until you install them again.

## Build and run

Open `WalkSpeed.xcodeproj`, choose your team under **Signing & Capabilities**,
pick your iPhone and press **Run**.

To do the same from the command line, run the deploy script. It makes a
release build, installs it on the first paired iPhone (or the one you name)
and launches it:

```sh
scripts/deploy.sh
scripts/deploy.sh '<iPhone name>'
```

Run it from a Terminal window on the Mac. Code signing needs your login
keychain, and background sessions such as SSH can't unlock it.

Before the first install, set up the iPhone:

1. Turn on Developer Mode: Settings → Privacy & Security → Developer Mode.
2. If you sign with a free Apple ID, trust your developer certificate after
   the first install: Settings → General → VPN & Device Management → your
   Apple ID → Trust.

After the first install over USB, Xcode can also install over Wi-Fi when the
iPhone and the Mac are on the same network.

### Simulator

The Simulator can fake a walk. This one heads north from Piccadilly Circus at
1.7 m/s (6.1 km/h, just over the default limit) and sends a location every
second:

```sh
xcrun simctl location booted start --speed=1.7 --interval=1 \
  51.5101,-0.1340 51.5136,-0.1376 51.5171,-0.1409
```

## Tests

```sh
swift test --package-path Packages/WalkSpeedCore
```

The `WalkSpeed` scheme's test action runs the same tests.

## Project layout

```text
WalkSpeed/                iOS app
├── App/                  entry point
├── Monitoring/           location, audio and the monitor tying them together
├── Settings/             saved preferences and the settings screen
└── Views/                main screen components
Packages/WalkSpeedCore/   platform-independent logic and its tests
scripts/                  tooling
```

## Contributing

Commits follow Conventional Commits and branch names follow Conventional
Branch; see [CONTRIBUTING.md](CONTRIBUTING.md).
