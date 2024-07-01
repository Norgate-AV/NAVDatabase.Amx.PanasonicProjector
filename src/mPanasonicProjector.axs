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

constant long TL_DRIVE          = 1
constant long TL_SOCKET_CHECK   = 2

constant integer REQUIRED_POWER_ON      = 1
constant integer REQUIRED_POWER_OFF     = 2

constant integer ACTUAL_POWER_ON        = 1
constant integer ACTUAL_POWER_OFF       = 2
constant integer ACTUAL_WARMING         = 3
constant integer ACTUAL_COOLING         = 4

constant integer INPUT_VGA_1            = 1
constant integer INPUT_RGB_1            = 2
constant integer INPUT_VIDEO_1          = 3
constant integer INPUT_SVIDEO_1         = 4
constant integer INPUT_DVI_1            = 5
constant integer INPUT_SDI_1            = 6
constant integer INPUT_HDMI_1           = 7
constant integer INPUT_DIGITAL_LINK_1   = 8

constant char INPUT_COMMANDS[][NAV_MAX_CHARS]   =   {
                                                        'RG1',
                                                        'RG2',
                                                        'VID',
                                                        'SVD',
                                                        'DVI',
                                                        'SDI',
                                                        'HD1',
                                                        'DL1'
                                                    }

constant integer SHUTTER_OPEN       = 1
constant integer SHUTTER_CLOSED     = 2

constant integer FREEZE_ON          = 1
constant integer FREEZE_OFF         = 2

constant integer GET_MODEL          = 1
constant integer GET_POWER          = 2
constant integer GET_INPUT          = 3
constant integer GET_LAMP1          = 4
constant integer GET_LAMP2          = 5
constant integer GET_SHUTT          = 6
constant integer GET_ASPECT         = 7
constant integer GET_FREEZE         = 8
constant integer GET_VOLUME         = 9

constant integer MODE_SERIAL       = 1
constant integer MODE_IP_DIRECT    = 2
constant integer MODE_IP_INDIRECT  = 3

constant char MODE_HEADER[][NAV_MAX_CHARS]         = { {NAV_STX_CHAR}, {'00'}, {NAV_STX_CHAR} }
constant char MODE_DELIMITER[][NAV_MAX_CHARS]      = { {NAV_ETX_CHAR}, {NAV_CR_CHAR}, {NAV_ETX_CHAR} }

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

volatile _NAVProjector object

volatile long driveTick[]   = { 200 }
volatile long socketCheck[] = { 3000 }

volatile integer loop = 0

volatile integer pollSequence = GET_MODEL
volatile integer pollSequenceEnabled[9]    = { true, true, true, true, true, true, true, true, true }

volatile integer lamp1QueryCommand

volatile char id[2] = 'ZZ'

volatile char baudRate[NAV_MAX_CHARS]    = '9600'

volatile integer autoImageRequired

volatile integer mode = MODE_SERIAL

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

define_function SendString(char payload[]) {
    payload = "payload, MODE_DELIMITER[mode]"

    if (secureCommandRequired && ModeIsIp(mode)) {
        payload = "NAVMd5GetHash(GetMd5Message(credential, md5Seed)), payload"
    }

    send_string dvPort, "payload"
}


define_function char[NAV_MAX_BUFFER] BuildProtocol(char message[]) {
    return "MODE_HEADER[mode], 'AD', id, ';', message"
}


define_function SendQuery(integer query) {
    if (!pollSequenceEnabled[query]) {
        return
    }

    switch (query) {
        case GET_MODEL:     { SendString(BuildProtocol("'QID'")) }
        case GET_POWER:     { SendString(BuildProtocol("'Q$S'")) }
        case GET_INPUT:     { SendString(BuildProtocol("'QIN'")) }
        case GET_LAMP1:     { SendString(BuildProtocol(LAMP_1_QUERY_COMMANDS[lamp1QueryCommand])) }
        case GET_LAMP2:     { SendString(BuildProtocol("'Q$L:2'")) }
        case GET_SHUTT:     { SendString(BuildProtocol("'QSH'")) }
        case GET_ASPECT:    { SendString(BuildProtocol('QSE')) }
        case GET_VOLUME:    { SendString(BuildProtocol("'QAV'")) }
        default:            { SendQuery(GET_POWER) }
    }
}


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


define_function SetPower(integer state) {
    switch (state) {
        case REQUIRED_POWER_ON: { SendString(BuildProtocol("'PON'")) }
        case REQUIRED_POWER_OFF: { SendString(BuildProtocol("'POF'")) }
    }
}


define_function SetInput(integer input) { SendString(BuildProtocol("'IIS:', INPUT_COMMANDS[input]")) }

define_function SetVolume(sinteger level) { SendString(BuildProtocol("'AVL:', itoa(level)")) }

define_function SetShutter(integer state) {
    switch (state) {
        case SHUTTER_OPEN: { SendString(BuildProtocol("'OSH:0'")) }
        case SHUTTER_CLOSED: { SendString(BuildProtocol("'OSH:1'")) }
    }
}


define_function integer ModeIsIp(integer mode) {
    return mode == MODE_IP_DIRECT || mode == MODE_IP_INDIRECT
}


define_function Drive() {
    if (!connectionStarted && ModeIsIp(mode)) {
        return;
    }

    if (secureCommandRequired && !length_array(md5Seed) && ModeIsIp(mode)) {
        return;
    }

    if (!module.Device.SocketConnection.IsConnected && ModeIsIp(mode)) {
        return;
    }

    loop++

    switch (loop) {
        case 1:
        case 6:
        case 11:
        case 16: { SendQuery(pollSequence); return }
        case 21: { loop = 0; return }
        default: {
            if (module.CommandBusy) { return }

            if (object.Display.PowerState.Required && (object.Display.PowerState.Required == object.Display.PowerState.Actual)) { object.Display.PowerState.Required = 0; return }
            if (object.Display.Input.Required && (object.Display.Input.Required == object.Display.Input.Actual)) { object.Display.Input.Required = 0; return }
            if (object.Display.VideoMute.Required && (object.Display.VideoMute.Required == object.Display.VideoMute.Actual)) { object.Display.VideoMute.Required = 0; return }
            if (object.Display.Aspect.Required && (object.Display.Aspect.Required == object.Display.Aspect.Actual)) { object.Display.Aspect.Required = 0; return }
            if (object.Freeze.Required && (object.Freeze.Required == object.Freeze.Actual)) { object.Freeze.Required = 0; return }

            if (object.Display.PowerState.Required && (object.Display.PowerState.Required != object.Display.PowerState.Actual) && (object.Display.PowerState.Actual != ACTUAL_WARMING) && (object.Display.PowerState.Actual != ACTUAL_COOLING)) {
                SetPower(object.Display.PowerState.Required)
                module.CommandBusy = true
                wait 50 module.CommandBusy = false
                pollSequence = GET_POWER
                return
            }

            if (object.Display.Input.Required && (object.Display.PowerState.Actual == ACTUAL_POWER_ON) && (object.Display.Input.Required != object.Display.Input.Actual)) {
                SetInput(object.Display.Input.Required)
                module.CommandBusy = true
                wait 20 module.CommandBusy = false
                pollSequence = GET_INPUT
                return
            }

            if (object.Display.VideoMute.Required && (object.Display.PowerState.Actual == ACTUAL_POWER_ON) && (object.Display.VideoMute.Required != object.Display.VideoMute.Actual)) {
                SetShutter(object.Display.VideoMute.Required)
                module.CommandBusy = true
                wait 10 module.CommandBusy = false
                pollSequence = GET_SHUTT
                return
            }

            if (object.Freeze.Required && (object.Display.PowerState.Actual == ACTUAL_POWER_ON) && (object.Freeze.Required != object.Freeze.Actual)) {
                //SetShutter(object.Display.VideoMute.Required)
                module.CommandBusy = true
                wait 10 module.CommandBusy = false
                pollSequence = GET_FREEZE
                return
            }

            if (object.Display.Aspect.Required && (object.Display.PowerState.Required == ACTUAL_POWER_ON) && (object.Display.Aspect.Required != object.Display.Aspect.Actual)) {
                switch (object.Display.Aspect.Required) {
                    case 1: { SendString(BuildProtocol('VSE:0')) }    //Normal
                    case 2: { SendString(BuildProtocol('VSE:5')) }    //Native
                    case 3: { SendString(BuildProtocol('VSE:2')) }    //Wide
                    case 4: { SendString(BuildProtocol('VSE:1')) }    //4x3
                    case 5: { SendString(BuildProtocol('VSE:9')) }    //H-Fit
                    case 6: { SendString(BuildProtocol('VSE:10')) }    //V-Fit
                    case 7: { SendString(BuildProtocol('VSE:6')) }    //Full
                }

                module.CommandBusy = true
                wait 10 module.CommandBusy = false
                pollSequence = GET_ASPECT;
                return;
            }

            if (autoImageRequired && (object.Display.PowerState.Required == ACTUAL_POWER_ON)) {
                SendString(BuildProtocol('OAS')); module.CommandBusy = true; wait 10 module.CommandBusy = false;    //Auto Image
                autoImageRequired = false
            }

            if ([vdvObject, MENU_FUNC]) { SendString(BuildProtocol('OMN')) module.CommandBusy = true; wait 5 module.CommandBusy = false }
            if ([vdvObject, MENU_UP]) { SendString(BuildProtocol('OCU')) module.CommandBusy = true; wait 5 module.CommandBusy = false }
            if ([vdvObject, MENU_DN]) { SendString(BuildProtocol('OCD')) module.CommandBusy = true; wait 5 module.CommandBusy = false }
            if ([vdvObject, MENU_LT]) { SendString(BuildProtocol('OCL')) module.CommandBusy = true; wait 5 module.CommandBusy = false }
            if ([vdvObject, MENU_RT]) { SendString(BuildProtocol('OCR')) module.CommandBusy = true; wait 5 module.CommandBusy = false }
            if ([vdvObject, MENU_SELECT]) { SendString(BuildProtocol('OEN')) module.CommandBusy = true; wait 5 module.CommandBusy = false }
            if ([vdvObject, MENU_CANCEL]) { SendString(BuildProtocol('OBK')) module.CommandBusy = true; wait 5 module.CommandBusy = false }
            if ([vdvObject, MENU_DISPLAY]) { SendString(BuildProtocol('OOS')) module.CommandBusy = true; wait 5 module.CommandBusy = false }
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
        active (NAVStartsWith(data, MODE_HEADER[mode])): {
            remove_string(data, MODE_HEADER[mode], 1)

            if (NAVStartsWith(data, 'ER')) {
                pollSequence = GET_MODEL
                return
            }

            switch (pollSequence) {
                case GET_POWER: {
                    switch (data) {
                        case '0': { object.Display.PowerState.Actual = ACTUAL_POWER_OFF; if (pollSequenceEnabled[GET_LAMP1]) pollSequence = GET_LAMP1; }
                        case '1': { object.Display.PowerState.Actual = ACTUAL_WARMING; if (pollSequenceEnabled[GET_LAMP1]) pollSequence = GET_LAMP1; }
                        case '2': {
                            object.Display.PowerState.Actual = ACTUAL_POWER_ON

                            select {
                                active (!object.Display.Input.Initialized): { pollSequence = GET_INPUT }
                                active (!object.Display.VideoMute.Initialized): { pollSequence = GET_SHUTT }
                                //active (!object.Display.Volume.Level.Initialized): { pollSequence = GET_VOLUME }
                                //active (!object.Freeze.Initialized): { pollSequence = GET_FREEZE }
                                //active (!object.Display.Aspect.Initialized): { pollSequence = GET_ASPECT }
                                active (true): {
                                    if (pollSequenceEnabled[GET_LAMP1]) { pollSequence = GET_LAMP1 }
                                }
                            }
                        }
                        case '3': { object.Display.PowerState.Actual = ACTUAL_COOLING; if (pollSequenceEnabled[GET_LAMP1]) pollSequence = GET_LAMP1; }
                    }
                }
                case GET_INPUT: {
                    select {
                        active (NAVContains(data, "'RG1'")): { object.Display.Input.Actual = INPUT_VGA_1; pollSequence = GET_POWER; object.Display.Input.Initialized = true }
                        active (NAVContains(data, "'RG2'")): { object.Display.Input.Actual = INPUT_RGB_1; pollSequence = GET_POWER; object.Display.Input.Initialized = true }
                        active (NAVContains(data, "'VID'")): { object.Display.Input.Actual = INPUT_VIDEO_1; pollSequence = GET_POWER; object.Display.Input.Initialized = true }
                        active (NAVContains(data, "'SVD'")): { object.Display.Input.Actual = INPUT_SVIDEO_1; pollSequence = GET_POWER; object.Display.Input.Initialized = true }
                        active (NAVContains(data, "'DVI'")): { object.Display.Input.Actual = INPUT_DVI_1; pollSequence = GET_POWER; object.Display.Input.Initialized = true }
                        active (NAVContains(data, "'SDI'")): { object.Display.Input.Actual = INPUT_SDI_1; pollSequence = GET_POWER; object.Display.Input.Initialized = true }
                        active (NAVContains(data, "'HD1'")): { object.Display.Input.Actual = INPUT_HDMI_1; pollSequence = GET_POWER; object.Display.Input.Initialized = true }
                        active (NAVContains(data, "'DL1'")): { object.Display.Input.Actual = INPUT_DIGITAL_LINK_1; pollSequence = GET_POWER; object.Display.Input.Initialized = true }
                    }
                }
                case GET_LAMP1: {
                    if (length_array(data) == 4) {
                        stack_var integer temp

                        temp = atoi(data)

                        if (temp != object.LampHours[1].Actual) {
                            object.LampHours[1].Actual = temp
                            send_string vdvObject, "'LAMPTIME-', itoa(object.LampHours[1].Actual)"
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

                        if (temp != object.LampHours[2].Actual) {
                            object.LampHours[2].Actual = temp
                            send_string vdvObject, "'LAMPTIME-', itoa(object.LampHours[2].Actual)"
                        }

                        pollSequence = GET_POWER
                    }
                }
                case GET_SHUTT: {
                    switch (data) {
                        case '0': { object.Display.VideoMute.Actual = SHUTTER_OPEN; pollSequence = GET_POWER; object.Display.VideoMute.Initialized = true }
                        case '1': { object.Display.VideoMute.Actual = SHUTTER_CLOSED; pollSequence = GET_POWER; object.Display.VideoMute.Initialized = true }
                    }
                }
                case GET_FREEZE: {
                    switch (data) {
                        case '0': { object.Freeze.Actual = FREEZE_OFF; pollSequence = GET_POWER; object.Freeze.Initialized = true }
                        case '1': { object.Freeze.Actual = FREEZE_ON; pollSequence = GET_POWER; object.Freeze.Initialized = true }
                    }
                }
                case GET_ASPECT: {
                    switch (atoi(data)) {
                        case 0: { object.Display.Aspect.Actual = 1; pollSequence = GET_POWER; object.Display.Aspect.Initialized = true }
                        case 5: { object.Display.Aspect.Actual = 2; pollSequence = GET_POWER; object.Display.Aspect.Initialized = true}
                        case 2: { object.Display.Aspect.Actual = 3; pollSequence = GET_POWER; object.Display.Aspect.Initialized = true}
                        case 1: { object.Display.Aspect.Actual = 4; pollSequence = GET_POWER; object.Display.Aspect.Initialized = true}
                        case 10: { object.Display.Aspect.Actual = 6; pollSequence = GET_POWER; object.Display.Aspect.Initialized = true}
                        case 9: { object.Display.Aspect.Actual = 5; pollSequence = GET_POWER; object.Display.Aspect.Initialized = true}
                        case 6: { object.Display.Aspect.Actual = 7; pollSequence = GET_POWER; object.Display.Aspect.Initialized = true }
                    }
                }
                case GET_VOLUME: {
                    object.Display.Volume.Level.Actual = atoi(data)
                    send_level vdvObject, 1, object.Display.Volume.Level.Actual * 255 / 63
                    object.Display.Volume.Level.Initialized = true
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
                    mode = MODE_SERIAL
                }
                case 'IP_DIRECT': {
                    mode = MODE_IP_DIRECT
                }
                case 'IP_INDIRECT': {
                    mode = MODE_IP_INDIRECT
                }
            }
        }
        case NAV_MODULE_PROPERTY_EVENT_ID: {
            id = format('%02d', atoi(event.Args[1]))
        }
        case NAV_MODULE_PROPERTY_EVENT_BAUDRATE: {
            baudRate = event.Args[1]

            if ((mode == MODE_SERIAL) && device_id(event.Device)) {
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
                NAVStringGather(module.RxBuffer, MODE_DELIMITER[mode])
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
                    case 'ON': { object.Display.PowerState.Required = REQUIRED_POWER_ON; Drive() }
                    case 'OFF': { object.Display.PowerState.Required = REQUIRED_POWER_OFF; object.Display.Input.Required = 0; Drive() }
                }
            }
            case 'MUTE': {
                if (object.Display.PowerState.Actual == ACTUAL_POWER_ON) {
                    switch (message.Parameter[1]) {
                        case 'ON': { object.Display.VideoMute.Required = SHUTTER_CLOSED; Drive() }
                        case 'OFF': { object.Display.VideoMute.Required = SHUTTER_OPEN; Drive() }
                    }
                }
            }
            case 'ADJUST': {
                if (object.Display.PowerState.Actual == ACTUAL_POWER_ON) {
                    autoImageRequired = true
                }
            }
            case 'ASPECT': {
                if (object.Display.PowerState.Actual == ACTUAL_POWER_ON) {
                    switch (message.Parameter[1]) {
                        case 'NORMAL': { object.Display.Aspect.Required = 1; Drive() }
                        case 'NATIVE': { object.Display.Aspect.Required = 2; Drive() }
                        case 'WIDE': { object.Display.Aspect.Required = 3; Drive() }
                        case '4x3': { object.Display.Aspect.Required = 4; Drive() }
                        case 'H_FIT': { object.Display.Aspect.Required = 5; Drive() }
                        case 'V_FIT': { object.Display.Aspect.Required = 6; Drive() }
                        case 'FULL': { object.Display.Aspect.Required = 7; Drive() }
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
                            case '1': { object.Display.PowerState.Required = REQUIRED_POWER_ON; object.Display.Input.Required = INPUT_VGA_1; Drive() }
                        }
                    }
                    case 'RGB': {
                        switch (message.Parameter[2]) {
                            case '1': { object.Display.PowerState.Required = REQUIRED_POWER_ON; object.Display.Input.Required = INPUT_RGB_1; Drive() }
                        }
                    }
                    case 'HDMI': {
                        switch (message.Parameter[2]) {
                            case '1': { object.Display.PowerState.Required = REQUIRED_POWER_ON; object.Display.Input.Required = INPUT_HDMI_1; Drive() }
                        }
                    }
                    case 'DVI': {
                        switch (message.Parameter[2]) {
                            case '1': { object.Display.PowerState.Required = REQUIRED_POWER_ON; object.Display.Input.Required = INPUT_DVI_1; Drive() }
                        }
                    }
                    case 'DIGITAL_LINK': {
                        switch (message.Parameter[2]) {
                            case '1': { object.Display.PowerState.Required = REQUIRED_POWER_ON; object.Display.Input.Required = INPUT_DIGITAL_LINK_1; Drive() }
                        }
                    }
                    case 'S-VIDEO': {
                        switch (message.Parameter[2]) {
                            case '1': { object.Display.PowerState.Required = REQUIRED_POWER_ON; object.Display.Input.Required = INPUT_SVIDEO_1; Drive() }
                        }
                    }
                    case 'COMPOSITE': {
                        switch (message.Parameter[2]) {
                            case '1': { object.Display.PowerState.Required = REQUIRED_POWER_ON; object.Display.Input.Required = INPUT_VIDEO_1; Drive() }
                        }
                    }
                    case 'SDI': {
                        switch (message.Parameter[2]) {
                            case '1': { object.Display.PowerState.Required = REQUIRED_POWER_ON; object.Display.Input.Required = INPUT_SDI_1; Drive() }
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
                if (object.Display.PowerState.Required) {
                    switch (object.Display.PowerState.Required) {
                        case REQUIRED_POWER_ON: { object.Display.PowerState.Required = REQUIRED_POWER_OFF; object.Display.Input.Required = 0; Drive() }
                        case REQUIRED_POWER_OFF: { object.Display.PowerState.Required = REQUIRED_POWER_ON; Drive() }
                    }
                }
                else {
                    switch (object.Display.PowerState.Actual) {
                        case ACTUAL_POWER_ON: { object.Display.PowerState.Required = REQUIRED_POWER_OFF; object.Display.Input.Required = 0; Drive() }
                        case ACTUAL_POWER_OFF: { object.Display.PowerState.Required = REQUIRED_POWER_ON; Drive() }
                    }
                }
            }
            case PWR_ON: { object.Display.PowerState.Required = REQUIRED_POWER_ON; Drive() }
            case PWR_OFF: { object.Display.PowerState.Required = REQUIRED_POWER_OFF; object.Display.Input.Required = 0; Drive() }
            case PIC_MUTE: {
                if (object.Display.VideoMute.Required) {
                    switch (object.Display.VideoMute.Required) {
                        case SHUTTER_CLOSED: { object.Display.PowerState.Required = SHUTTER_OPEN; Drive() }
                        case SHUTTER_OPEN: { object.Display.PowerState.Required = SHUTTER_CLOSED; Drive() }
                    }
                }
                else {
                    switch (object.Display.VideoMute.Actual) {
                        case SHUTTER_CLOSED: { object.Display.PowerState.Required = SHUTTER_OPEN; Drive() }
                        case SHUTTER_OPEN: { object.Display.PowerState.Required = SHUTTER_CLOSED; Drive() }
                    }
                }
            }
            case PIC_MUTE_ON: {
                if (object.Display.PowerState.Actual == ACTUAL_POWER_ON) {
                    object.Display.VideoMute.Required = SHUTTER_CLOSED; Drive()
                }
            }
        }
    }
    off: {
        switch (channel.channel) {
            case PIC_MUTE_ON: {
                if (object.Display.PowerState.Actual == ACTUAL_POWER_ON) {
                    object.Display.VideoMute.Required = SHUTTER_OPEN; Drive()
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

    [vdvObject, LAMP_WARMING_FB]    = (object.Display.PowerState.Actual == ACTUAL_WARMING)
    [vdvObject, LAMP_COOLING_FB]    = (object.Display.PowerState.Actual == ACTUAL_COOLING)
    [vdvObject, PIC_MUTE_FB]        = (object.Display.VideoMute.Actual == SHUTTER_CLOSED)
    [vdvObject, POWER_FB] = (object.Display.PowerState.Actual == ACTUAL_POWER_ON)
    [vdvObject, 31]    =    (object.Display.Input.Actual == INPUT_VGA_1)
    [vdvObject, 32]    =    (object.Display.Input.Actual == INPUT_RGB_1)
    [vdvObject, 33]    =    (object.Display.Input.Actual == INPUT_VIDEO_1)
    [vdvObject, 34]    =    (object.Display.Input.Actual == INPUT_SVIDEO_1)
    [vdvObject, 35]    =    (object.Display.Input.Actual == INPUT_DVI_1)
    [vdvObject, 36]    =    (object.Display.Input.Actual == INPUT_SDI_1)
    [vdvObject, 37]    =    (object.Display.Input.Actual == INPUT_HDMI_1)
    [vdvObject, 38]    =    (object.Display.Input.Actual == INPUT_DIGITAL_LINK_1)
}


(***********************************************************)
(*                     END OF PROGRAM                      *)
(*        DO NOT PUT ANY CODE BELOW THIS COMMENT           *)
(***********************************************************)

