MODULE_NAME='mPanasonicProjector'   (
                                        dev vdvObject,
                                        dev dvPort
                                    )

(***********************************************************)
#DEFINE USING_NAV_MODULE_BASE_CALLBACKS
#DEFINE USING_NAV_MODULE_BASE_PROPERTY_EVENT_CALLBACK
#DEFINE USING_NAV_MODULE_BASE_PASSTHRU_EVENT_CALLBACK
#DEFINE USING_NAV_STRING_GATHER_CALLBACK
#DEFINE USING_NAV_LOGIC_ENGINE_EVENT_CALLBACK
#DEFINE USING_NAV_DEVICE_PRIORITY_QUEUE_SEND_NEXT_ITEM_EVENT_CALLBACK
#DEFINE USING_NAV_DEVICE_PRIORITY_QUEUE_FAILED_RESPONSE_EVENT_CALLBACK
#include 'NAVFoundation.LogicEngine.axi'
#include 'NAVFoundation.ModuleBase.axi'
#include 'NAVFoundation.SocketUtils.axi'
#include 'NAVFoundation.StringUtils.axi'
#include 'NAVFoundation.DevicePriorityQueue.axi'
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

constant long TL_SOCKET_CHECK           = 1

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

constant char INPUT_SNAPI_PARAMS[][NAV_MAX_CHARS]   =   {
                                                            'VGA,1',
                                                            'RGB,1',
                                                            'COMPOSITE,1',
                                                            'S-VIDEO,1',
                                                            'DVI,1',
                                                            'SDI,1',
                                                            'HDMI,1',
                                                            'DIGITAL_LINK,1'
                                                        }

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

constant integer ASPECT_NORMAL         = 1
constant integer ASPECT_4X3            = 2
constant integer ASPECT_WIDE           = 3
constant integer ASPECT_NATIVE         = 4
constant integer ASPECT_FULL           = 5
constant integer ASPECT_H_FIT          = 6
constant integer ASPECT_V_FIT          = 7

constant char ASPECT_SNAPI_PARAMS[][NAV_MAX_CHARS]  =   {
                                                            'NORMAL',
                                                            '4x3',
                                                            'WIDE',
                                                            'NATIVE',
                                                            'FULL',
                                                            'H_FIT',
                                                            'V_FIT'
                                                        }

constant char ASPECT_COMMANDS[][NAV_MAX_CHARS]  =   {
                                                        '0',    // Normal
                                                        '1',    // 4x3
                                                        '2',    // Wide
                                                        '5',    // Native
                                                        '6',    // Full
                                                        '9',    // H-Fit
                                                        '10'    // V-Fit
                                                    }

constant integer VIDEO_MUTE_ON      = 1
constant integer VIDEO_MUTE_OFF     = 2

constant integer FREEZE_ON          = 1
constant integer FREEZE_OFF         = 2

constant integer GET_MODEL          = 1
constant integer GET_POWER          = 2
constant integer GET_INPUT          = 3
constant integer GET_LAMP1          = 4
constant integer GET_LAMP2          = 5
constant integer GET_VIDEO_MUTE     = 6
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

volatile long socketCheck[] = { 3000 }

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

    if (ModeIsIp(mode)) {
        NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                    NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_STRING_TO,
                                                dvPort,
                                                payload))
    }

    send_string dvPort, "payload"
}


define_function char[NAV_MAX_BUFFER] BuildProtocol(char message[]) {
    return "MODE_HEADER[mode], 'AD', id, ';', message"
}


define_function SendQuery(integer query) {
    if (priorityQueue.Busy) {
        return
    }

    if (!pollSequenceEnabled[query]) {
        return
    }

    switch (query) {
        case GET_MODEL:         { EnqueueQueryItem(BuildProtocol('QID')) }
        case GET_POWER:         { EnqueueQueryItem(BuildProtocol('Q$S')) }
        case GET_INPUT:         { EnqueueQueryItem(BuildProtocol('QIN')) }
        case GET_LAMP1:         { EnqueueQueryItem(BuildProtocol(LAMP_1_QUERY_COMMANDS[lamp1QueryCommand])) }
        case GET_LAMP2:         { EnqueueQueryItem(BuildProtocol('Q$L:2')) }
        case GET_VIDEO_MUTE:    { EnqueueQueryItem(BuildProtocol('QSH')) }
        case GET_ASPECT:        { EnqueueQueryItem(BuildProtocol('QSE')) }
        case GET_VOLUME:        { EnqueueQueryItem(BuildProtocol('QAV')) }
        default:                { SendQuery(GET_POWER) }
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

    NAVLogicEngineStop()
}


define_function SetPower(integer state) {
    switch (state) {
        case REQUIRED_POWER_ON:     { EnqueueCommandItem(BuildProtocol('PON')) }
        case REQUIRED_POWER_OFF:    { EnqueueCommandItem(BuildProtocol('POF')) }
    }
}


define_function SetInput(integer input) {
    EnqueueCommandItem(BuildProtocol("'IIS:', INPUT_COMMANDS[input]"))
}


define_function SetAspect(integer aspect) {
    EnqueueCommandItem(BuildProtocol("'VSE:', ASPECT_COMMANDS[aspect]"))
}


define_function SetVolume(sinteger level) {
    EnqueueCommandItem(BuildProtocol("'AVL:', itoa(level)"))
}


define_function SetShutter(integer state) {
    switch (state) {
        case VIDEO_MUTE_ON:     { EnqueueCommandItem(BuildProtocol('OSH:1')) }
        case VIDEO_MUTE_OFF:    { EnqueueCommandItem(BuildProtocol('OSH:0')) }
    }
}


define_function integer ModeIsIp(integer mode) {
    return mode == MODE_IP_DIRECT || mode == MODE_IP_INDIRECT
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


define_function EnqueueCommandItem(char item[]) {
    NAVDevicePriorityQueueEnqueue(priorityQueue, item, true)
}


define_function EnqueueQueryItem(char item[]) {
    NAVDevicePriorityQueueEnqueue(priorityQueue, item, false)
}


#IF_DEFINED USING_NAV_DEVICE_PRIORITY_QUEUE_SEND_NEXT_ITEM_EVENT_CALLBACK
define_function NAVDevicePriorityQueueSendNextItemEventCallback(char item[]) {
    SendString(item)
}
#END_IF


#IF_DEFINED USING_NAV_DEVICE_PRIORITY_QUEUE_FAILED_RESPONSE_EVENT_CALLBACK
define_function NAVDevicePriorityQueueFailedResponseEventCallback(_NAVDevicePriorityQueue queue) {
    module.Device.IsCommunicating = false
}
#END_IF


#IF_DEFINED USING_NAV_LOGIC_ENGINE_EVENT_CALLBACK
define_function NAVLogicEngineEventCallback(_NAVLogicEngineEvent args) {
    if (!connectionStarted && ModeIsIp(mode)) {
        return;
    }

    if (secureCommandRequired && !length_array(md5Seed) && ModeIsIp(mode)) {
        return;
    }

    if (!module.Device.SocketConnection.IsConnected && ModeIsIp(mode)) {
        return;
    }

    if (priorityQueue.Busy) {
        return;
    }

    switch (args.Name) {
        case NAV_LOGIC_ENGINE_EVENT_QUERY: {
            SendQuery(pollSequence)
            return
        }
        case NAV_LOGIC_ENGINE_EVENT_ACTION: {
            if (module.CommandBusy) {
                return
            }

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
                pollSequence = GET_VIDEO_MUTE
                return
            }

            // if (object.Freeze.Required && (object.Display.PowerState.Actual == ACTUAL_POWER_ON) && (object.Freeze.Required != object.Freeze.Actual)) {
            //     //SetShutter(object.Display.VideoMute.Required)
            //     module.CommandBusy = true
            //     wait 10 module.CommandBusy = false
            //     pollSequence = GET_FREEZE
            //     return
            // }

            if (object.Display.Aspect.Required && (object.Display.PowerState.Required == ACTUAL_POWER_ON) && (object.Display.Aspect.Required != object.Display.Aspect.Actual)) {
                SetAspect(object.Display.Aspect.Required)

                module.CommandBusy = true
                wait 10 module.CommandBusy = false
                pollSequence = GET_ASPECT;
                return;
            }

            if (autoImageRequired && (object.Display.PowerState.Required == ACTUAL_POWER_ON)) {
                EnqueueCommandItem(BuildProtocol('OAS')); module.CommandBusy = true; wait 10 module.CommandBusy = false;    //Auto Image
                autoImageRequired = false
            }

            if ([vdvObject, MENU_FUNC]) { EnqueueCommandItem(BuildProtocol('OMN')) module.CommandBusy = true; wait 5 module.CommandBusy = false }
            if ([vdvObject, MENU_UP]) { EnqueueCommandItem(BuildProtocol('OCU')) module.CommandBusy = true; wait 5 module.CommandBusy = false }
            if ([vdvObject, MENU_DN]) { EnqueueCommandItem(BuildProtocol('OCD')) module.CommandBusy = true; wait 5 module.CommandBusy = false }
            if ([vdvObject, MENU_LT]) { EnqueueCommandItem(BuildProtocol('OCL')) module.CommandBusy = true; wait 5 module.CommandBusy = false }
            if ([vdvObject, MENU_RT]) { EnqueueCommandItem(BuildProtocol('OCR')) module.CommandBusy = true; wait 5 module.CommandBusy = false }
            if ([vdvObject, MENU_SELECT]) { EnqueueCommandItem(BuildProtocol('OEN')) module.CommandBusy = true; wait 5 module.CommandBusy = false }
            if ([vdvObject, MENU_CANCEL]) { EnqueueCommandItem(BuildProtocol('OBK')) module.CommandBusy = true; wait 5 module.CommandBusy = false }
            if ([vdvObject, MENU_DISPLAY]) { EnqueueCommandItem(BuildProtocol('OOS')) module.CommandBusy = true; wait 5 module.CommandBusy = false }
        }
    }
}
#END_IF


define_function char[NAV_MAX_BUFFER] GetError(integer error) {
    switch (error) {
        case 401:   { return 'Command cannot be executed' }
        case 402:   { return 'Invalid parameter' }
        default:    { return 'Unknown error' }
    }
}


#IF_DEFINED USING_NAV_STRING_GATHER_CALLBACK
define_function NAVStringGatherCallback(_NAVStringGatherResult args) {
    stack_var char data[NAV_MAX_BUFFER]
    stack_var char delimiter[NAV_MAX_CHARS]

    data = args.Data
    delimiter = args.Delimiter

    if (ModeIsIp(mode)) {
        NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                    NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_PARSING_STRING_FROM,
                                                dvPort,
                                                data))
    }

    data = NAVStripRight(data, length_array(delimiter))

    select {
        active (NAVStartsWith(data, 'NTCONTROL')): {
            data = NAVStripLeft(data, 10);

            secureCommandRequired = atoi(remove_string(data, ' ', 1));

            if (secureCommandRequired) {
                md5Seed = data;
            }

            connectionStarted = true;
        }
        active (NAVStartsWith(data, MODE_HEADER[mode])): {
            stack_var char last[NAV_MAX_BUFFER]

            last = NAVDevicePriorityQueueGetLastMessage(priorityQueue)

            remove_string(data, MODE_HEADER[mode], 1)

            if (NAVStartsWith(data, 'ER')) {
                pollSequence = GET_MODEL

                // ER401 - Command cannot be executed
                // ER402 - Invalid parameter

                // Common reasons for ER401:
                // - The projector is in a state where the command cannot be executed
                // --- Some commands cannot be executed when the projector is in standby
                // --- Sending 'QIN' (Get Input) when the projector is in standby will return ER401
                // --- Sending 'QSE' (Get Aspect) when the projector isn't displaying an image will return ER401

                remove_string(data, 'ER', 1)

                NAVErrorLog(NAV_LOG_LEVEL_ERROR,
                            "'mPanasonicProjector => Error: Command [', last, MODE_DELIMITER[mode], '] failed with error code ', data, ': ',
                                GetError(atoi(data))")

                NAVDevicePriorityQueueGoodResponse(priorityQueue)
                return
            }

            // Only process the response if the last command was a query
            remove_string(last, ';', 1)
            if (!NAVStartsWith(last, 'Q')) {
                NAVDevicePriorityQueueGoodResponse(priorityQueue)
                return
            }

            select {
                active (NAVContains(last, 'QID')): {
                    select {
                        active (NAVContains(data, 'RZ')): {
                            pollSequenceEnabled[GET_LAMP1] = false
                            pollSequenceEnabled[GET_LAMP2] = false
                            pollSequence = GET_POWER
                        }
                        active (NAVContains(data, 'MZ')): {
                            pollSequenceEnabled[GET_LAMP1] = false
                            pollSequenceEnabled[GET_LAMP2] = false
                            pollSequence = GET_POWER
                        }
                        active (NAVContains(data, 'RW')): {
                            pollSequenceEnabled[GET_LAMP1] = false
                            pollSequenceEnabled[GET_LAMP2] = false
                            pollSequence = GET_POWER
                        }
                        active (NAVContains(data, 'FRQ')): {
                            pollSequenceEnabled[GET_LAMP1] = false
                            pollSequenceEnabled[GET_LAMP2] = false
                            pollSequence = GET_POWER
                        }
                        active (NAVContains(data, 'FW')): {
                            lamp1QueryCommand = 1
                            pollSequenceEnabled[GET_LAMP2] = false
                            pollSequence = GET_POWER
                        }
                        active (NAVContains(data, 'DX')): {
                            lamp1QueryCommand = 1
                            pollSequenceEnabled[GET_LAMP2] = false
                            pollSequence = GET_POWER
                        }
                    }
                }
                active (NAVContains(last, 'Q$S')): {
                    switch (data) {
                        case '0': {
                            object.Display.PowerState.Actual = ACTUAL_POWER_OFF

                            if (pollSequenceEnabled[GET_LAMP1]) {
                                pollSequence = GET_LAMP1
                            }
                        }
                        case '1': {
                            object.Display.PowerState.Actual = ACTUAL_WARMING

                            if (pollSequenceEnabled[GET_LAMP1]) {
                                pollSequence = GET_LAMP1
                            }
                        }
                        case '3': {
                            object.Display.PowerState.Actual = ACTUAL_COOLING

                            if (pollSequenceEnabled[GET_LAMP1]) {
                                pollSequence = GET_LAMP1
                            }
                        }
                        case '2': {
                            object.Display.PowerState.Actual = ACTUAL_POWER_ON

                            select {
                                active (!object.Display.Input.Initialized): {
                                    pollSequence = GET_INPUT
                                }
                                active (!object.Display.VideoMute.Initialized): {
                                    pollSequence = GET_VIDEO_MUTE
                                }
                                // active (!object.Display.Volume.Level.Initialized): {
                                //     pollSequence = GET_VOLUME
                                // }
                                // active (!object.Freeze.Initialized): {
                                //     pollSequence = GET_FREEZE
                                // }
                                // active (!object.Display.Aspect.Initialized): {
                                //     pollSequence = GET_ASPECT
                                // }
                                active (true): {
                                    if (pollSequenceEnabled[GET_LAMP1]) {
                                        pollSequence = GET_LAMP1
                                    }
                                }
                            }
                        }
                    }
                }
                active (NAVContains(last, 'QIN')): {
                    stack_var integer input

                    input = NAVFindInArrayString(INPUT_COMMANDS, data)

                    if (input) {
                        object.Display.Input.Actual = input
                        object.Display.Input.Initialized = true
                    }

                    pollSequence = GET_POWER
                }
                active (NAVContains(last, 'Q$L')): {
                    stack_var integer hours

                    hours = atoi(data)

                    if (hours != object.LampHours[1].Actual) {
                        object.LampHours[1].Actual = hours
                        send_string vdvObject, "'LAMPTIME-', itoa(object.LampHours[1].Actual)"
                    }

                    if (pollSequenceEnabled[GET_LAMP2]) {
                        pollSequence = GET_LAMP2;
                    }
                    else {
                        pollSequence = GET_POWER;
                    }
                }
                active (NAVContains(last, 'Q$L:2')): {
                    stack_var integer hours

                    hours = atoi(data)

                    if (hours != object.LampHours[2].Actual) {
                        object.LampHours[2].Actual = hours
                        send_string vdvObject, "'LAMPTIME-', itoa(object.LampHours[2].Actual)"
                    }

                    pollSequence = GET_POWER
                }
                active (NAVContains(last, 'QSH')): {
                    switch (data) {
                        case '0': {
                            object.Display.VideoMute.Actual = VIDEO_MUTE_OFF
                            object.Display.VideoMute.Initialized = true
                            pollSequence = GET_POWER
                        }
                        case '1': {
                            object.Display.VideoMute.Actual = VIDEO_MUTE_ON
                            object.Display.VideoMute.Initialized = true
                            pollSequence = GET_POWER
                        }
                    }
                }
                active (NAVContains(last, 'QSE')): {
                    stack_var integer aspect

                    aspect = NAVFindInArrayString(ASPECT_COMMANDS, data)

                    if (aspect) {
                        object.Display.Aspect.Actual = aspect
                        object.Display.Aspect.Initialized = true
                    }

                    pollSequence = GET_POWER
                }
                active (NAVContains(last, 'QAV')): {
                    stack_var sinteger level

                    level = atoi(data)

                    if (level != object.Display.Volume.Level.Actual) {
                        object.Display.Volume.Level.Actual = level
                        NAVSendLevel(vdvObject, VOL_LVL, type_cast(level * 255 / 63))
                    }

                    object.Display.Volume.Level.Initialized = true
                    pollSequence = GET_POWER
                }
                // active (NAVContains(last, 'QSH')): {
                //     switch (data) {
                //         case '0': { object.Freeze.Actual = FREEZE_OFF; pollSequence = GET_POWER; object.Freeze.Initialized = true }
                //         case '1': { object.Freeze.Actual = FREEZE_ON; pollSequence = GET_POWER; object.Freeze.Initialized = true }
                //     }
                // }
                // active (true): {
                //     pollSequence = GET_POWER
                // }
            }

            NAVDevicePriorityQueueGoodResponse(priorityQueue)
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

    EnqueueCommandItem(event.Payload)
}
#END_IF


define_function HandleSnapiMessage(_NAVSnapiMessage message, tdata data) {
    switch (message.Header) {
        case 'POWER': {
            switch (message.Parameter[1]) {
                case 'ON': {
                    object.Display.PowerState.Required = REQUIRED_POWER_ON
                }
                case 'OFF': {
                    object.Display.PowerState.Required = REQUIRED_POWER_OFF
                    object.Display.Input.Required = 0
                }
            }
        }
        case 'MUTE': {
            if (object.Display.PowerState.Actual != ACTUAL_POWER_ON) {
                return
            }

            switch (message.Parameter[1]) {
                case 'ON': {
                    object.Display.VideoMute.Required = VIDEO_MUTE_ON
                }
                case 'OFF': {
                    object.Display.VideoMute.Required = VIDEO_MUTE_OFF
                }
            }
        }
        case 'ADJUST': {
            if (object.Display.PowerState.Actual != ACTUAL_POWER_ON) {
                return
            }

            autoImageRequired = true
        }
        case 'ASPECT': {
            if (object.Display.PowerState.Actual != ACTUAL_POWER_ON) {
                return
            }

            object.Display.Aspect.Required = NAVFindInArrayString(ASPECT_SNAPI_PARAMS, message.Parameter[1])
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
            stack_var integer input
            stack_var char inputCommand[NAV_MAX_CHARS]

            NAVTrimStringArray(message.Parameter)
            inputCommand = NAVArrayJoinString(message.Parameter, ',')

            input = NAVFindInArrayString(INPUT_SNAPI_PARAMS, inputCommand)

            if (input <= 0) {
                NAVErrorLog(NAV_LOG_LEVEL_WARNING,
                            "'mPanasonicProjector => Invalid input: ', inputCommand")

                return
            }

            object.Display.PowerState.Required = REQUIRED_POWER_ON
            object.Display.Input.Required = input
        }
    }
}


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

        NAVLogicEngineStart()
    }
    string: {
        CommunicationTimeOut(30)

        if (data.device.port == 0) {
            NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                        NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_STRING_FROM,
                                                    data.device,
                                                    data.text))
        }

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

        NAVErrorLog(NAV_LOG_LEVEL_ERROR,
                    "'mPanasonicProjector => OnError: ', NAVGetSocketError(type_cast(data.number))")
    }
}


data_event[vdvObject] {
    online: {
        NAVCommand(data.device, "'PROPERTY-RMS_MONITOR_ASSET_PROPERTY,MONITOR_ASSET_DESCRIPTION,Video Projector'")
        NAVCommand(data.device, "'PROPERTY-RMS_MONITOR_ASSET_PROPERTY,MONITOR_ASSET_MANUFACTURER_URL,www.panasonic.com'")
        NAVCommand(data.device, "'PROPERTY-RMS_MONITOR_ASSET_PROPERTY,MONITOR_ASSET_MANUFACTURER_NAME,Panasonic'")
    }
    command: {
        stack_var _NAVSnapiMessage message

        NAVParseSnapiMessage(data.text, message)

        HandleSnapiMessage(message, data)
    }
}


channel_event[vdvObject, 0] {
    on: {
        switch (channel.channel) {
            case POWER: {
                if (object.Display.PowerState.Required) {
                    switch (object.Display.PowerState.Required) {
                        case REQUIRED_POWER_ON: {
                            object.Display.PowerState.Required = REQUIRED_POWER_OFF
                            object.Display.Input.Required = 0
                        }
                        case REQUIRED_POWER_OFF: {
                            object.Display.PowerState.Required = REQUIRED_POWER_ON
                        }
                    }
                }
                else {
                    switch (object.Display.PowerState.Actual) {
                        case ACTUAL_POWER_ON: {
                            object.Display.PowerState.Required = REQUIRED_POWER_OFF
                            object.Display.Input.Required = 0
                        }
                        case ACTUAL_POWER_OFF: {
                            object.Display.PowerState.Required = REQUIRED_POWER_ON
                        }
                    }
                }
            }
            case PWR_ON: { object.Display.PowerState.Required = REQUIRED_POWER_ON }
            case PWR_OFF: { object.Display.PowerState.Required = REQUIRED_POWER_OFF; object.Display.Input.Required = 0 }
            case PIC_MUTE: {
                if (object.Display.VideoMute.Required) {
                    switch (object.Display.VideoMute.Required) {
                        case VIDEO_MUTE_ON: { object.Display.PowerState.Required = VIDEO_MUTE_OFF }
                        case VIDEO_MUTE_OFF: { object.Display.PowerState.Required = VIDEO_MUTE_ON }
                    }
                }
                else {
                    switch (object.Display.VideoMute.Actual) {
                        case VIDEO_MUTE_ON: { object.Display.PowerState.Required = VIDEO_MUTE_OFF }
                        case VIDEO_MUTE_OFF: { object.Display.PowerState.Required = VIDEO_MUTE_ON }
                    }
                }
            }
            case PIC_MUTE_ON: {
                if (object.Display.PowerState.Actual == ACTUAL_POWER_ON) {
                    object.Display.VideoMute.Required = VIDEO_MUTE_ON
                }
            }
        }
    }
    off: {
        switch (channel.channel) {
            case PIC_MUTE_ON: {
                if (object.Display.PowerState.Actual == ACTUAL_POWER_ON) {
                    object.Display.VideoMute.Required = VIDEO_MUTE_OFF
                }
            }
        }
    }
}


timeline_event[TL_SOCKET_CHECK] {
    MaintainSocketConnection()
}


timeline_event[TL_NAV_FEEDBACK] {
    [vdvObject, NAV_IP_CONNECTED]	= (module.Device.SocketConnection.IsConnected)
    [vdvObject, DEVICE_COMMUNICATING] = (module.Device.IsCommunicating)
    [vdvObject, DATA_INITIALIZED] = (module.Device.IsInitialized)

    [vdvObject, LAMP_WARMING_FB]    = (object.Display.PowerState.Actual == ACTUAL_WARMING)
    [vdvObject, LAMP_COOLING_FB]    = (object.Display.PowerState.Actual == ACTUAL_COOLING)
    [vdvObject, PIC_MUTE_FB]        = (object.Display.VideoMute.Actual == VIDEO_MUTE_ON)
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

