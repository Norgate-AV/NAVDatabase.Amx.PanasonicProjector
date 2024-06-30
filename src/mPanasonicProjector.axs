MODULE_NAME='mPanasonicProjector'   (
                                        dev vdvObject,
                                        dev dvPort
                                    )

(***********************************************************)
#DEFINE USING_NAV_MODULE_BASE_CALLBACKS
#DEFINE USING_NAV_MODULE_BASE_PROPERTY_EVENT_CALLBACK
#DEFINE USING_NAV_MODULE_BASE_PASSTHRU_EVENT_CALLBACK
#DEFINE USING_NAV_STRING_GATHER_CALLBACK
#include 'NAVFoundation.ModuleBase.axi'
#include 'NAVFoundation.SocketUtils.axi'
#include 'NAVFoundation.StringUtils.axi'
#include 'NAVFoundation.Cryptography.Md5.axi'

/*
 _   _                       _          ___     __
| \ | | ___  _ __ __ _  __ _| |_ ___   / \ \   / /
|  \| |/ _ \| '__/ _` |/ _` | __/ _ \ / _ \ \ / /
| |\  | (_) | | | (_| | (_| | ||  __// ___ \ V /
|_| \_|\___/|_|  \__, |\__,_|\__\___/_/   \_\_/
                 |___/

MIT License

Copyright (c) 2023 Norgate AV Services Limited

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

(***********************************************************)
(*          DEVICE NUMBER DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_DEVICE

(***********************************************************)
(*               CONSTANT DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_CONSTANT
constant long TL_DRIVE    = 1
constant long TL_SOCKET_CHECK = 2

constant integer REQUIRED_POWER_ON    = 1
constant integer REQUIRED_POWER_OFF    = 2

constant integer ACTUAL_POWER_ON    = 1
constant integer ACTUAL_POWER_OFF    = 2
constant integer ACTUAL_WARMING        = 3
constant integer ACTUAL_COOLING        = 4

constant integer REQUIRED_INPUT_VGA_1    = 1
constant integer REQUIRED_INPUT_RGB_1    = 2
constant integer REQUIRED_INPUT_VIDEO_1    = 3
constant integer REQUIRED_INPUT_SVIDEO_1    = 4
constant integer REQUIRED_INPUT_DVI_1    = 5
constant integer REQUIRED_INPUT_SDI_1    = 6
constant integer REQUIRED_INPUT_HDMI_1    = 7
constant integer REQUIRED_INPUT_DIGITAL_LINK_1    = 8

constant integer ACTUAL_INPUT_VGA_1    = 1
constant integer ACTUAL_INPUT_RGB_1    = 2
constant integer ACTUAL_INPUT_VIDEO_1    = 3
constant integer ACTUAL_INPUT_SVIDEO_1    = 4
constant integer ACTUAL_INPUT_DVI_1    = 5
constant integer ACTUAL_INPUT_SDI_1    = 6
constant integer ACTUAL_INPUT_HDMI_1    = 7
constant integer ACTUAL_INPUT_DIGITAL_LINK_1    = 8

constant char INPUT_COMMANDS[][NAV_MAX_CHARS]    = { 'RG1',
                            'RG2',
                            'VID',
                            'SVD',
                            'DVI',
                            'SDI',
                            'HD1',
                            'DL1' }

constant integer REQUIRED_SHUTTER_OPEN    = 1
constant integer REQUIRED_SHUTTER_CLOSED    = 2

constant integer ACTUAL_SHUTTER_OPEN    = 1
constant integer ACTUAL_SHUTTER_CLOSED    = 2

constant integer REQUIRED_FREEZE_ON    = 1
constant integer REQUIRED_FREEZE_OFF    = 2

constant integer ACTUAL_FREEZE_ON    = 1
constant integer ACTUAL_FREEZE_OFF    = 2

constant integer GET_MODEL    = 1
constant integer GET_POWER    = 2
constant integer GET_INPUT    = 3
constant integer GET_LAMP1    = 4
constant integer GET_LAMP2    = 5
constant integer GET_SHUTT    = 6
constant integer GET_ASPECT    = 7
constant integer GET_FREEZE    = 8
constant integer GET_VOLUME    = 9

constant integer COMM_MODE_SERIAL    = 1
constant integer COMM_MODE_IP_DIRECT    = 2
constant integer COMM_MODE_IP_INDIRECT    = 3

constant char COMM_MODE_HEADER[][NAV_MAX_CHARS]    = { {NAV_STX_CHAR}, {'00'}, {NAV_STX_CHAR} }
constant char COMM_MODE_DELIMITER[][NAV_MAX_CHARS]    = { {NAV_ETX_CHAR}, {NAV_CR_CHAR}, {NAV_ETX_CHAR} }

constant char LAMP_1_QUERY_COMMANDS[][NAV_MAX_CHARS]    = { 'Q$L', 'Q$L:1' }

constant integer DEFAULT_IP_PORT    = 1024

(***********************************************************)
(*              DATA TYPE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_TYPE

(***********************************************************)
(*               VARIABLE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_VARIABLE

volatile _NAVProjector uProj

volatile long socketCheck[] = { 3000 }

volatile integer loop
volatile integer pollSequence = GET_MODEL
volatile integer pollSequenceEnabled[9]    = { true, true, true, true, true, true, true, true, true }

volatile integer requiredPower
volatile integer requiredInput
volatile integer requiredShutter
volatile integer requiredAspect
volatile integer actualAspect
volatile integer requiredFreeze
volatile integer actualFreeze
volatile sinteger requiredVolume
volatile sinteger actualVolume

volatile integer inputInitialized
volatile integer shutterInitialized
volatile integer freezeInitialized
volatile integer aspectInitialized
volatile integer volumeInitialized

volatile integer lamp1QueryCommand

volatile long driveTick[] = { 200 }

volatile integer powerBusy

volatile integer commandBusy
volatile integer commandLockOut

volatile char id[2] = 'ZZ'

volatile char baudRate[NAV_MAX_CHARS]    = '9600'

volatile integer autoImageRequired

volatile integer commMode = COMM_MODE_SERIAL

volatile integer secureCommandRequired
volatile integer connectionStarted
volatile char md5Seed[255]

volatile _NAVCredential credential = { 'admin1', 'password' }

(***********************************************************)
(*               LATCHING DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_LATCHING

(***********************************************************)
(*       MUTUALLY EXCLUSIVE DEFINITIONS GO BELOW           *)
(***********************************************************)
DEFINE_MUTUALLY_EXCLUSIVE

(***********************************************************)
(*        SUBROUTINE/FUNCTION DEFINITIONS GO BELOW         *)
(***********************************************************)
(* EXAMPLE: DEFINE_FUNCTION <RETURN_TYPE> <NAME> (<PARAMETERS>) *)
(* EXAMPLE: DEFINE_CALL '<NAME>' (<PARAMETERS>) *)
define_function SendStringRaw(char payload[]) {
    NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'String To ', NAVConvertDPSToAscii(dvPort), '-[', payload, ']'")
    send_string dvPort, "payload"
}


define_function SendString(char message[]) {
    char payload[NAV_MAX_BUFFER]

    payload = "COMM_MODE_HEADER[commMode], 'AD', id, ';', message, COMM_MODE_DELIMITER[commMode]"

    if (secureCommandRequired && CommModeIsIP(commMode)) {
        payload = "NAVMd5GetHash(GetMd5Message(credential, md5Seed)), payload"
    }

    SendStringRaw(payload)
}


define_function SendQuery(integer param) {
    if (pollSequenceEnabled[param]) {
        switch (param) {
            case GET_MODEL: SendString("'QID'")
            case GET_POWER: SendString("'Q$S'")
            case GET_INPUT: SendString("'QIN'")
            case GET_LAMP1: SendString(LAMP_1_QUERY_COMMANDS[lamp1QueryCommand])
            case GET_LAMP2: SendString("'Q$L:2'")
            case GET_SHUTT: SendString("'QSH'")
            case GET_ASPECT: { SendString('QSE') }            //Get Aspect
            case GET_VOLUME: SendString("'QAV'")
        }
    }
}


// define_function TimeOut() {
//     cancel_wait 'CommsTimeOut'

//     wait 300 'CommsTimeOut' {
//         [vdvObject, DEVICE_COMMUNICATING] = false

//         if (commMode == COMM_MODE_IP_DIRECT) {
//             NAVClientSocketClose(dvPort.PORT)
//         }
//     }
// }


define_function CommunicationTimeOut(integer timeout) {
    cancel_wait 'TimeOut'

    module.Device.IsCommunicating = true

    wait (timeout * 10) 'TimeOut' {
        module.Device.IsCommunicating = false
    }
}


define_function Reset() {
    module.Device.SocketConnection.IsConnected = false
    module.Device.IsCommunicating = false
    module.Device.IsInitialized = false

    connectionStarted = false
    loop = 0
    NAVTimelineStop(TL_DRIVE)
}


define_function SetPower(integer param) {
    switch (param) {
        case REQUIRED_POWER_ON: { SendString("'PON'") }
        case REQUIRED_POWER_OFF: { SendString("'POF'") }
    }
}


define_function SetInput(integer param) { SendString("'IIS:', INPUT_COMMANDS[param]") }

define_function SetVolume(sinteger param) { SendString("'AVL:', itoa(param)") }

define_function SetShutter(integer param) {
    switch (requiredShutter) {
        case REQUIRED_SHUTTER_OPEN: { SendString("'OSH:0'") }
        case REQUIRED_SHUTTER_CLOSED: { SendString("'OSH:1'") }
    }
}


define_function integer CommModeIsIP(integer mode) {
    return mode == COMM_MODE_IP_DIRECT || mode == COMM_MODE_IP_INDIRECT
}


define_function Drive() {
    if (!connectionStarted && CommModeIsIP(commMode)) {
        return;
    }

    if (secureCommandRequired && !length_array(md5Seed) && CommModeIsIP(commMode)) {
        return;
    }

    if (!module.Device.SocketConnection.IsConnected && CommModeIsIP(commMode)) {
        return;
    }

    loop++

    switch (loop) {
        case 1:
        case 6:
        case 11:
        case 16: { SendQuery(pollSequence); return }
        case 21: { loop = 1; return }
        default: {
            if (commandLockOut) { return }
            if (requiredPower && (requiredPower == uProj.Display.PowerState.Actual)) { requiredPower = 0; return }
            if (requiredInput && (requiredInput == uProj.Display.Input.Actual)) { requiredInput = 0; return }
            if (requiredShutter && (requiredShutter == uProj.Display.VideoMute.Actual)) { requiredShutter = 0; return }
            if (requiredAspect && (requiredAspect == actualAspect)) { requiredAspect = 0; return }
            if (requiredFreeze && (requiredFreeze == actualFreeze)) { requiredFreeze = 0; return }

            if (requiredPower && (requiredPower != uProj.Display.PowerState.Actual) && (uProj.Display.PowerState.Actual != ACTUAL_WARMING) && (uProj.Display.PowerState.Actual != ACTUAL_COOLING)) {
                commandBusy = true
                SetPower(requiredPower)
                commandLockOut = true
                wait 50 commandLockOut = false
                pollSequence = GET_POWER
                return
            }

            if (requiredInput && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON) && (requiredInput != uProj.Display.Input.Actual)) {
                commandBusy = true
                SetInput(requiredInput)
                commandLockOut = true
                wait 20 commandLockOut = false
                pollSequence = GET_INPUT
                return
            }

            if (requiredShutter && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON) && (requiredShutter != uProj.Display.VideoMute.Actual)) {
                commandBusy = true
                SetShutter(requiredShutter)
                commandLockOut = true
                wait 10 commandLockOut = false
                pollSequence = GET_SHUTT
                return
            }

            if (requiredFreeze && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON) && (requiredFreeze != actualFreeze)) {
                commandBusy = true
                //SetShutter(requiredShutter)
                commandLockOut = true
                wait 10 commandLockOut = false
                pollSequence = GET_FREEZE
                return
            }

            if (requiredAspect && (uProj.Display.PowerState.Required == ACTUAL_POWER_ON) && (requiredAspect != actualAspect)) {
                switch (requiredAspect) {
                    case 1: { SendString('VSE:0') }    //Normal
                    case 2: { SendString('VSE:5') }    //Native
                    case 3: { SendString('VSE:2') }    //Wide
                    case 4: { SendString('VSE:1') }    //4x3
                    case 5: { SendString('VSE:9') }    //H-Fit
                    case 6: { SendString('VSE:10') }    //V-Fit
                    case 7: { SendString('VSE:6') }    //Full
                }

                commandLockOut = true
                wait 10 commandLockOut = false
                pollSequence = GET_ASPECT;
                return;
            }

            if (autoImageRequired && (uProj.Display.PowerState.Required == ACTUAL_POWER_ON)) {
                SendString('OAS'); commandLockout = true; wait 10 commandLockOut = false;    //Auto Image
                autoImageRequired = false
            }

            if ([vdvObject, MENU_FUNC]) { SendString('OMN') commandLockOut = true; wait 5 commandLockOut = false }
            if ([vdvObject, MENU_UP]) { SendString('OCU') commandLockOut = true; wait 5 commandLockOut = false }
            if ([vdvObject, MENU_DN]) { SendString('OCD') commandLockOut = true; wait 5 commandLockOut = false }
            if ([vdvObject, MENU_LT]) { SendString('OCL') commandLockOut = true; wait 5 commandLockOut = false }
            if ([vdvObject, MENU_RT]) { SendString('OCR') commandLockOut = true; wait 5 commandLockOut = false }
            if ([vdvObject, MENU_SELECT]) { SendString('OEN') commandLockOut = true; wait 5 commandLockOut = false }
            if ([vdvObject, MENU_CANCEL]) { SendString('OBK') commandLockOut = true; wait 5 commandLockOut = false }
            if ([vdvObject, MENU_DISPLAY]) { SendString('OOS') commandLockOut = true; wait 5 commandLockOut = false }
        }
    }
}


define_function MaintainSocketConnection() {
    if (module.Device.SocketConnection.IsConnected) {
        return
    }

    NAVClientSocketOpen(dvPort.PORT,
                        module.Device.SocketConnection.Address,
                        module.Device.SocketConnection.Port,
                        IP_TCP)
}


define_function char[NAV_MAX_BUFFER] GetMd5Message(_NAVCredential credential, char md5Seed[]) {
    return "credential.Username, ':', credential.Password, ':', md5Seed"
}


#IF_DEFINED USING_NAV_STRING_GATHER_CALLBACK
define_function NAVStringGatherCallback(_NAVStringGatherResult args) {
    stack_var char data[NAV_MAX_BUFFER]
    stack_var char delimiter[NAV_MAX_CHARS]

    data = args.Data
    delimiter = args.Delimiter

    NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_PARSING_STRING_FROM,
                                            dvPort,
                                            data))

    data = NAVStripRight(data, length_array(delimiter))

    select {
        active (NAVStartsWith(data, 'NTCONTROL')): {
            //Connection Started
            data = NAVStripLeft(data, 10);

            secureCommandRequired = atoi(remove_string(data, ' ', 1));

            if (secureCommandRequired) {
                md5Seed = data;
            }

            connectionStarted = true;
            loop = 0;
            Drive();
        }
        active (NAVStartsWith(data, COMM_MODE_HEADER[commMode])): {
            remove_string(data, COMM_MODE_HEADER[commMode], 1)

            if (NAVStartsWith(data, 'ER')) {
                pollSequence = GET_MODEL
                return
            }

            switch (pollSequence) {
                case GET_POWER: {
                    switch (data) {
                        case '0': { uProj.Display.PowerState.Actual = ACTUAL_POWER_OFF; if (pollSequenceEnabled[GET_LAMP1]) pollSequence = GET_LAMP1; }
                        case '1': { uProj.Display.PowerState.Actual = ACTUAL_WARMING; if (pollSequenceEnabled[GET_LAMP1]) pollSequence = GET_LAMP1; }
                        case '2': {
                            uProj.Display.PowerState.Actual = ACTUAL_POWER_ON

                            select {
                                active (!inputInitialized): { pollSequence = GET_INPUT }
                                active (!shutterInitialized): { pollSequence = GET_SHUTT }
                                //active (!volumeInitialized): { pollSequence = GET_VOLUME }
                                //active (!freezeInitialized): { pollSequence = GET_FREEZE }
                                //active (!aspectInitialized): { pollSequence = GET_ASPECT }
                                active (true): {
                                    if (pollSequenceEnabled[GET_LAMP1]) { pollSequence = GET_LAMP1 }
                                }
                            }
                        }
                        case '3': { uProj.Display.PowerState.Actual = ACTUAL_COOLING; if (pollSequenceEnabled[GET_LAMP1]) pollSequence = GET_LAMP1; }
                    }
                }
                case GET_INPUT: {
                    select {
                        active (NAVContains(data, "'RG1'")): { uProj.Display.Input.Actual = ACTUAL_INPUT_VGA_1; pollSequence = GET_POWER; inputInitialized = true }
                        active (NAVContains(data, "'RG2'")): { uProj.Display.Input.Actual = ACTUAL_INPUT_RGB_1; pollSequence = GET_POWER; inputInitialized = true }
                        active (NAVContains(data, "'VID'")): { uProj.Display.Input.Actual = ACTUAL_INPUT_VIDEO_1; pollSequence = GET_POWER; inputInitialized = true }
                        active (NAVContains(data, "'SVD'")): { uProj.Display.Input.Actual = ACTUAL_INPUT_SVIDEO_1; pollSequence = GET_POWER; inputInitialized = true }
                        active (NAVContains(data, "'DVI'")): { uProj.Display.Input.Actual = ACTUAL_INPUT_DVI_1; pollSequence = GET_POWER; inputInitialized = true }
                        active (NAVContains(data, "'SDI'")): { uProj.Display.Input.Actual = ACTUAL_INPUT_SDI_1; pollSequence = GET_POWER; inputInitialized = true }
                        active (NAVContains(data, "'HD1'")): { uProj.Display.Input.Actual = ACTUAL_INPUT_HDMI_1; pollSequence = GET_POWER; inputInitialized = true }
                        active (NAVContains(data, "'DL1'")): { uProj.Display.Input.Actual = ACTUAL_INPUT_DIGITAL_LINK_1; pollSequence = GET_POWER; inputInitialized = true }
                    }
                }
                case GET_LAMP1: {
                    if (length_array(data) == 4) {
                        stack_var integer temp

                        temp = atoi(data)

                        if (temp != uProj.LampHours[1].Actual) {
                            uProj.LampHours[1].Actual = temp
                            send_string vdvObject, "'LAMPTIME-', itoa(uProj.LampHours[1].Actual)"
                        }

                        if (pollSequenceEnabled[GET_LAMP2]) {
                            pollSequence = GET_LAMP2;
                        }
                        else {
                            pollSequence = GET_POWER;
                        }
                    }
                }
                case GET_LAMP2: {
                    if (length_array(data) == 4) {
                        stack_var integer temp

                        temp = atoi(data)

                        if (temp != uProj.LampHours[2].Actual) {
                            uProj.LampHours[2].Actual = temp
                            send_string vdvObject, "'LAMPTIME-', itoa(uProj.LampHours[2].Actual)"
                        }

                        pollSequence = GET_POWER
                    }
                }
                case GET_SHUTT: {
                    switch (data) {
                        case '0': { uProj.Display.VideoMute.Actual = ACTUAL_SHUTTER_OPEN; pollSequence = GET_POWER; shutterInitialized = true }
                        case '1': { uProj.Display.VideoMute.Actual = ACTUAL_SHUTTER_CLOSED; pollSequence = GET_POWER; shutterInitialized = true }
                    }
                }
                case GET_FREEZE: {
                    switch (data) {
                        case '0': { actualFreeze = ACTUAL_FREEZE_OFF; pollSequence = GET_POWER; freezeInitialized = true }
                        case '1': { actualFreeze = ACTUAL_FREEZE_ON; pollSequence = GET_POWER; freezeInitialized = true }
                    }
                }
                case GET_ASPECT: {
                    switch (atoi(data)) {
                        case 0: { actualAspect = 1; pollSequence = GET_POWER; aspectInitialized = true }
                        case 5: { actualAspect = 2; pollSequence = GET_POWER; aspectInitialized = true}
                        case 2: { actualAspect = 3; pollSequence = GET_POWER; aspectInitialized = true}
                        case 1: { actualAspect = 4; pollSequence = GET_POWER; aspectInitialized = true}
                        case 10: { actualAspect = 6; pollSequence = GET_POWER; aspectInitialized = true}
                        case 9: { actualAspect = 5; pollSequence = GET_POWER; aspectInitialized = true}
                        case 6: { actualAspect = 7; pollSequence = GET_POWER; aspectInitialized = true }
                    }
                }
                case GET_VOLUME: {
                    actualVolume = atoi(data)
                    send_level vdvObject, 1, actualVolume * 255 / 63
                    volumeInitialized = true
                    pollSequence = GET_POWER
                }
                case GET_MODEL: {    //Model
                    select {
                        active (NAVContains(data, 'RZ') > 0): { pollSequenceEnabled[GET_LAMP1] = 0; pollSequenceEnabled[GET_LAMP2] = 0; pollSequence = GET_POWER; }
                        active (NAVContains(data, 'MZ') > 0): { pollSequenceEnabled[GET_LAMP1] = 0; pollSequenceEnabled[GET_LAMP2] = 0; pollSequence = GET_POWER; }
                        active (NAVContains(data, 'RW') > 0): { pollSequenceEnabled[GET_LAMP1] = 0; pollSequenceEnabled[GET_LAMP2] = 0; pollSequence = GET_POWER; }
                        active (NAVContains(data, 'FRQ') > 0): { pollSequenceEnabled[GET_LAMP1] = 0; pollSequenceEnabled[GET_LAMP2] = 0; pollSequence = GET_POWER; }
                        active (NAVContains(data, 'FW') > 0): { lamp1QueryCommand = 1; pollSequenceEnabled[GET_LAMP2] = 0; pollSequence = GET_POWER; }
                        active (NAVContains(data, 'DX') > 0): { lamp1QueryCommand = 1; pollSequenceEnabled[GET_LAMP2] = 0; pollSequence = GET_POWER; }
                    }
                }
            }
        }
    }
}
#END_IF


#IF_DEFINED USING_NAV_MODULE_BASE_PROPERTY_EVENT_CALLBACK
define_function NAVModulePropertyEventCallback(_NAVModulePropertyEvent event) {
    if (event.Device != vdvObject) {
        return
    }

    switch (event.Name) {
        case NAV_MODULE_PROPERTY_EVENT_IP_ADDRESS: {
            module.Device.SocketConnection.Address = NAVTrimString(event.Args[1])
            NAVTimelineStart(TL_SOCKET_CHECK, socketCheck, TIMELINE_ABSOLUTE, TIMELINE_REPEAT)
        }
        case NAV_MODULE_PROPERTY_EVENT_PORT: {
            module.Device.SocketConnection.Port = atoi(event.Args[1])
        }
        case 'COMM_MODE': {
            switch (event.Args[1]) {
                case 'SERIAL': {
                    commMode = COMM_MODE_SERIAL
                }
                case 'IP_DIRECT': {
                    commMode = COMM_MODE_IP_DIRECT
                }
                case 'IP_INDIRECT': {
                    commMode = COMM_MODE_IP_INDIRECT
                }
            }
        }
        case NAV_MODULE_PROPERTY_EVENT_ID: {
            id = format('%02d', atoi(event.Args[1]))
        }
        case NAV_MODULE_PROPERTY_EVENT_BAUDRATE: {
            baudRate = event.Args[1]

            if ((commMode == COMM_MODE_SERIAL) && device_id(event.Device)) {
                NAVCommand(event.Device, "'SET BAUD ', baudRate, ',N,8,1 485 DISABLE'")
            }
        }
        case NAV_MODULE_PROPERTY_EVENT_USERNAME: {
            credential.Username = NAVTrimString(event.Args[1])
        }
        case NAV_MODULE_PROPERTY_EVENT_PASSWORD: {
            credential.Password = NAVTrimString(event.Args[1])
        }
    }
}
#END_IF


#IF_DEFINED USING_NAV_MODULE_BASE_PASSTHRU_EVENT_CALLBACK
define_function NAVModulePassthruEventCallback(_NAVModulePassthruEvent event) {
    if (event.Device != vdvObject) {
        return
    }

    SendString(event.Payload)
}
#END_IF


(***********************************************************)
(*                STARTUP CODE GOES BELOW                  *)
(***********************************************************)
DEFINE_START {
    create_buffer dvPort, module.RxBuffer.Data
    module.Device.SocketConnection.Socket = dvPort.PORT
    module.Device.SocketConnection.Port = DEFAULT_IP_PORT
}

(***********************************************************)
(*                THE EVENTS GO BELOW                      *)
(***********************************************************)
DEFINE_EVENT

data_event[dvPort] {
    online: {
        if (data.device.number != 0) {
            NAVCommand(data.device, "'SET BAUD ', baudRate, ',N,8,1 485 DISABLE'")
            NAVCommand(data.device, "'B9MOFF'")
            NAVCommand(data.device, "'CHARD-0'")
            NAVCommand(data.device, "'CHARDM-0'")
            NAVCommand(data.device, "'HSOFF'")
        }

        if (data.device.number == 0) {
            module.Device.SocketConnection.IsConnected = true
        }

        NAVTimelineStart(TL_DRIVE, driveTick, TIMELINE_ABSOLUTE, TIMELINE_REPEAT)
    }
    string: {
        CommunicationTimeOut(30)

        NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                    NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_STRING_FROM,
                                                data.device,
                                                data.text))
        select {
            active(true): {
                NAVStringGather(module.RxBuffer, COMM_MODE_DELIMITER[commMode])
            }
        }
    }
    offline: {
        if (data.device.number == 0) {
            NAVClientSocketClose(data.device.port)
            Reset()
        }
    }
    onerror: {
        if (data.device.number == 0) {
            Reset()
        }
    }
}


data_event[vdvObject] {
    online: {
        NAVCommand(data.device, "'PROPERTY-RMS_MONITOR_ASSET_PROPERTY, MONITOR_ASSET_DESCRIPTION, Video Projector'")
        NAVCommand(data.device, "'PROPERTY-RMS_MONITOR_ASSET_PROPERTY, MONITOR_ASSET_MANUFACTURER_URL, www.panasonic.com'")
        NAVCommand(data.device, "'PROPERTY-RMS_MONITOR_ASSET_PROPERTY, MONITOR_ASSET_MANUFACTURER_NAME, PANASONIC'")
    }
    command: {
        stack_var _NAVSnapiMessage message

        NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                    NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_COMMAND_FROM,
                                                data.device,
                                                data.text))

        NAVParseSnapiMessage(data.text, message)

        switch (message.Header) {
            case 'POWER': {
                switch (message.Parameter[1]) {
                    case 'ON': { requiredPower = REQUIRED_POWER_ON; Drive() }
                    case 'OFF': { requiredPower = REQUIRED_POWER_OFF; requiredInput = 0; Drive() }
                }
            }
            case 'MUTE': {
                if (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON) {
                    switch (message.Parameter[1]) {
                        case 'ON': { requiredShutter = REQUIRED_SHUTTER_CLOSED; Drive() }
                        case 'OFF': { requiredShutter = REQUIRED_SHUTTER_OPEN; Drive() }
                    }
                }
            }
            case 'ADJUST': {
                if (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON) {
                    autoImageRequired = true
                }
            }
            case 'ASPECT': {
                if (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON) {
                    switch (message.Parameter[1]) {
                        case 'NORMAL': { requiredAspect = 1; Drive() }
                        case 'NATIVE': { requiredAspect = 2; Drive() }
                        case 'WIDE': { requiredAspect = 3; Drive() }
                        case '4x3': { requiredAspect = 4; Drive() }
                        case 'H_FIT': { requiredAspect = 5; Drive() }
                        case 'V_FIT': { requiredAspect = 6; Drive() }
                        case 'FULL': { requiredAspect = 7; Drive() }
                    }
                }
            }
            case 'VOLUME': {
                switch (message.Parameter[1]) {
                    case 'ABS': {
                        SetVolume(atoi(message.Parameter[2]))
                        pollSequence = GET_VOLUME
                    }
                    default: {
                        SetVolume(atoi(message.Parameter[1]) * 63 / 255)
                        pollSequence = GET_VOLUME
                    }
                }
            }
            case 'INPUT': {
                switch (message.Parameter[1]) {
                    case 'VGA': {
                        switch (message.Parameter[2]) {
                            case '1': { requiredPower = REQUIRED_POWER_ON; requiredInput = REQUIRED_INPUT_VGA_1; Drive() }
                        }
                    }
                    case 'RGB': {
                        switch (message.Parameter[2]) {
                            case '1': { requiredPower = REQUIRED_POWER_ON; requiredInput = REQUIRED_INPUT_RGB_1; Drive() }
                        }
                    }
                    case 'HDMI': {
                        switch (message.Parameter[2]) {
                            case '1': { requiredPower = REQUIRED_POWER_ON; requiredInput = REQUIRED_INPUT_HDMI_1; Drive() }
                        }
                    }
                    case 'DVI': {
                        switch (message.Parameter[2]) {
                            case '1': { requiredPower = REQUIRED_POWER_ON; requiredInput = REQUIRED_INPUT_DVI_1; Drive() }
                        }
                    }
                    case 'DIGITAL_LINK': {
                        switch (message.Parameter[2]) {
                            case '1': { requiredPower = REQUIRED_POWER_ON; requiredInput = REQUIRED_INPUT_DIGITAL_LINK_1; Drive() }
                        }
                    }
                    case 'S-VIDEO': {
                        switch (message.Parameter[2]) {
                            case '1': { requiredPower = REQUIRED_POWER_ON; requiredInput = REQUIRED_INPUT_SVIDEO_1; Drive() }
                        }
                    }
                    case 'COMPOSITE': {
                        switch (message.Parameter[2]) {
                            case '1': { requiredPower = REQUIRED_POWER_ON; requiredInput = REQUIRED_INPUT_VIDEO_1; Drive() }
                        }
                    }
                    case 'SDI': {
                        switch (message.Parameter[2]) {
                            case '1': { requiredPower = REQUIRED_POWER_ON; requiredInput = REQUIRED_INPUT_SDI_1; Drive() }
                        }
                    }
                }
            }
        }
    }
}


channel_event[vdvObject, 0] {
    on: {
        switch (channel.channel) {
            case POWER: {
                if (requiredPower) {
                    switch (requiredPower) {
                        case REQUIRED_POWER_ON: { requiredPower = REQUIRED_POWER_OFF; requiredInput = 0; Drive() }
                        case REQUIRED_POWER_OFF: { requiredPower = REQUIRED_POWER_ON; Drive() }
                    }
                }
                else {
                    switch (uProj.Display.PowerState.Actual) {
                        case ACTUAL_POWER_ON: { requiredPower = REQUIRED_POWER_OFF; requiredInput = 0; Drive() }
                        case ACTUAL_POWER_OFF: { requiredPower = REQUIRED_POWER_ON; Drive() }
                    }
                }
            }
            case PWR_ON: { requiredPower = REQUIRED_POWER_ON; Drive() }
            case PWR_OFF: { requiredPower = REQUIRED_POWER_OFF; requiredInput = 0; Drive() }
            case PIC_MUTE: {
                if (requiredShutter) {
                    switch (requiredShutter) {
                        case REQUIRED_SHUTTER_CLOSED: { requiredPower = REQUIRED_SHUTTER_OPEN; Drive() }
                        case REQUIRED_SHUTTER_OPEN: { requiredPower = REQUIRED_SHUTTER_CLOSED; Drive() }
                    }
                }
                else {
                    switch (uProj.Display.VideoMute.Actual) {
                        case ACTUAL_SHUTTER_CLOSED: { requiredPower = REQUIRED_SHUTTER_OPEN; Drive() }
                        case ACTUAL_SHUTTER_OPEN: { requiredPower = REQUIRED_SHUTTER_CLOSED; Drive() }
                    }
                }
            }
            case PIC_MUTE_ON: {
                if (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON) {
                    requiredShutter = REQUIRED_SHUTTER_CLOSED; Drive()
                }
            }
        }
    }
    off: {
        switch (channel.channel) {
            case PIC_MUTE_ON: {
                if (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON) {
                    requiredShutter = REQUIRED_SHUTTER_OPEN; Drive()
                }
            }
        }
    }
}


timeline_event[TL_DRIVE] { Drive() }

timeline_event[TL_SOCKET_CHECK] { MaintainSocketConnection() }

timeline_event[TL_NAV_FEEDBACK] {
    [vdvObject, NAV_IP_CONNECTED]	= (module.Device.SocketConnection.IsConnected)
    [vdvObject, DEVICE_COMMUNICATING] = (module.Device.IsCommunicating)
    [vdvObject, DATA_INITIALIZED] = (module.Device.IsInitialized)

    [vdvObject, LAMP_WARMING_FB]    = (uProj.Display.PowerState.Actual == ACTUAL_WARMING)
    [vdvObject, LAMP_COOLING_FB]    = (uProj.Display.PowerState.Actual == ACTUAL_COOLING)
    [vdvObject, PIC_MUTE_FB]        = (uProj.Display.VideoMute.Actual == ACTUAL_SHUTTER_CLOSED)
    [vdvObject, POWER_FB] = (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON)
    [vdvObject, 31]    =    (uProj.Display.Input.Actual == ACTUAL_INPUT_VGA_1)
    [vdvObject, 32]    =    (uProj.Display.Input.Actual == ACTUAL_INPUT_RGB_1)
    [vdvObject, 33]    =    (uProj.Display.Input.Actual == ACTUAL_INPUT_VIDEO_1)
    [vdvObject, 34]    =    (uProj.Display.Input.Actual == ACTUAL_INPUT_SVIDEO_1)
    [vdvObject, 35]    =    (uProj.Display.Input.Actual == ACTUAL_INPUT_DVI_1)
    [vdvObject, 36]    =    (uProj.Display.Input.Actual == ACTUAL_INPUT_SDI_1)
    [vdvObject, 37]    =    (uProj.Display.Input.Actual == ACTUAL_INPUT_HDMI_1)
    [vdvObject, 38]    =    (uProj.Display.Input.Actual == ACTUAL_INPUT_DIGITAL_LINK_1)
}


(***********************************************************)
(*                     END OF PROGRAM                      *)
(*        DO NOT PUT ANY CODE BELOW THIS COMMENT           *)
(***********************************************************)

