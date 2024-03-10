# NAVDatabase.Amx.PanasonicProjector

<!-- <div align="center">
 <img src="./" alt="logo" width="200" />
</div> -->

---

[![CI](https://github.com/Norgate-AV/NAVDatabase.Amx.PanasonicProjector/actions/workflows/main.yml/badge.svg)](https://github.com/Norgate-AV/NAVDatabase.Amx.PanasonicProjector/actions/workflows/main.yml)
[![Conventional Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-%23FE5196?logo=conventionalcommits&logoColor=white)](https://conventionalcommits.org)
[![Commitizen friendly](https://img.shields.io/badge/commitizen-friendly-brightgreen.svg)](http://commitizen.github.io/cz-cli/)
[![MIT license](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

AMX NetLinx module for Panasonic projectors.

## Contents :book:

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

-   [Installation :zap:](#installation-zap)
-   [Usage :rocket:](#usage-rocket)
-   [Team :soccer:](#team-soccer)
-   [Contributors :sparkles:](#contributors-sparkles)
-   [LICENSE :balance_scale:](#license-balance_scale)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Installation :zap:

This module can be installed using [Scoop](https://scoop.sh/).

```powershell
scoop bucket add norgateav-amx https://github.com/Norgate-AV/scoop-norgateav-amx
scoop install navdatabase-amx-panasonic-projector
```

## Usage :rocket:

```netlinx
DEFINE_DEVICE

// The real device
dvPanasonicProjector            = 5001:1:0          // Serial/RS232 Connection

// or
// dvPanasonicProjector         = 0:4:0             // IP/Socket Connection

// Virtual Devices
vdvPanasonicProjector           = 33201:1:0         // The interface between the device and the control system

// User Interface
dvTP                            = 10001:1:0         // Main UI


define_module 'mPanasonicProjector' PanasonicProjectorComm(vdvPanasonicProjector, dvPanasonicProjector)


DEFINE_EVENT

data_event[vdvPanasonicProjector] {
    online: {
        // If using IP/Socket Connection
        // send_command data.device, "'PROPERTY-IP_ADDRESS,', '192.168.1.21'"

        // Set an alternative baud rate for serial connection. Default is 9600
        // send_command data.device, "'PROPERTY-BAUD_RATE,', '38400'"

        // send_command data.device, "'PROPERTY-USER_NAME,', 'admin1'"
        // send_command data.device, "'PROPERTY-PASSWORD,', 'panasonic'"
    }
}


// Trigger power state
button_event[dvTP, 1]
button_event[dvTP, 2] {
    push: {
        switch (button.input.channel) {
            case 1: {
                pulse[vdvPanasonicProjector, PWR_ON]

                // or
                send_command vdvPanasonicProjector, "'POWER-ON'"
            }
            case 2: {
                pulse[vdvPanasonicProjector, PWR_OFF]

                // or
                send_command vdvPanasonicProjector, "'POWER-OFF'"
            }
        }
    }
}


// Trigger input switch
button_event[dvTP, 11]
button_event[dvTP, 12] {
    push: {
        // Triggering an input switch will automatically turn the projector on
        // and switch to the selected input
        switch (button.input.channel) {
            case 11: {
                send_command vdvPanasonicProjector, "'INPUT-HDMI,1'"
            }
            case 12: {
                send_command vdvPanasonicProjector, "'INPUT-DIGITAL_LINK,1'"
            }
        }
    }
}

```

## Team :soccer:

This project is maintained by the following person(s) and a bunch of [awesome contributors](https://github.com/Norgate-AV/NAVDatabase.Amx.PanasonicProjector/graphs/contributors).

<table>
  <tr>
    <td align="center"><a href="https://github.com/damienbutt"><img src="https://avatars.githubusercontent.com/damienbutt?v=4?s=100" width="100px;" alt=""/><br /><sub><b>Damien Butt</b></sub></a><br /></td>
  </tr>
</table>

## Contributors :sparkles:

<!-- ALL-CONTRIBUTORS-BADGE:START - Do not remove or modify this section -->

[![All Contributors](https://img.shields.io/badge/all_contributors-1-orange.svg?style=flat-square)](#contributors-)

<!-- ALL-CONTRIBUTORS-BADGE:END -->

Thanks go to these awesome people ([emoji key](https://allcontributors.org/docs/en/emoji-key)):

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->

<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->

<!-- ALL-CONTRIBUTORS-LIST:END -->

This project follows the [all-contributors](https://allcontributors.org) specification.
Contributions of any kind are welcome!

## LICENSE :balance_scale:

[MIT](LICENSE)
