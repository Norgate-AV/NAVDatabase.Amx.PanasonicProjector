MODULE_NAME='mPanasonicProjector'   (
                                        dev vdvObject,
                                        dev dvPort
                                    )

(***********************************************************)
#include 'NAVFoundation.ModuleBase.axi'
#include 'NAVFoundation.SocketUtils.axi'
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
constant long TL_IP_CLIENT_CHECK = 2

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

constant integer DEFAULT_TCP_PORT    = 1024

(***********************************************************)
(*              DATA TYPE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_TYPE

(***********************************************************)
(*               VARIABLE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_VARIABLE

volatile _NAVProjector uProj
volatile _NAVModule uModule

volatile long ltIPClientCheck[] = { 3000 }

volatile integer iLoop
volatile integer iPollSequence = GET_MODEL
volatile integer iPollSequenceEnabled[9]    = { true, true, true, true, true, true, true, true, true }

volatile integer iRequiredPower
volatile integer iRequiredInput
volatile integer iRequiredShutter
volatile integer iRequiredAspect
volatile integer iActualAspect
volatile integer irequiredFreeze
volatile integer iActualFreeze
volatile sinteger siRequiredVolume
volatile sinteger siActualVolume

volatile integer iInputInitialized
volatile integer iShutterInitialized
volatile integer iFreezeInitialized
volatile integer iAspectInitialized
volatile integer iVolumeInitialized

volatile integer iLamp1QueryCommand

volatile long ltDrive[] = { 200 }

volatile integer iSemaphore
volatile char cRxBuffer[NAV_MAX_BUFFER]

volatile integer iPowerBusy

volatile integer iCommandBusy
volatile integer iCommandLockOut

volatile char cID[2] = 'ZZ'

volatile char cBaudRate[NAV_MAX_CHARS]    = '9600'

volatile integer iAutoImageRequired

volatile _NAVSocketConnection uIPConnection

volatile integer iCommMode = COMM_MODE_SERIAL

volatile integer iSecureCommandRequired
volatile integer iConnectionStarted
volatile char cMD5RandomNumber[255]
volatile char cMD5StringToEncode[255]

volatile char cUserName[NAV_MAX_CHARS] = 'admin1'
volatile char cPassword[NAV_MAX_CHARS] = 'password'

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
define_function SendStringRaw(char cPayload[]) {
    NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'String To ', NAVConvertDPSToAscii(dvPort), '-[', cPayload, ']'")
    send_string dvPort, "cPayload"
}


define_function SendString(char cParam[]) {
    char cPayload[NAV_MAX_BUFFER]

    cPayload = "COMM_MODE_HEADER[iCommMode], 'AD', cID, ';', cParam, COMM_MODE_DELIMITER[iCommMode]"

    if (iSecureCommandRequired && CommModeIsIP(iCommMode)) {
        cPayload = "NAVMd5GetHash(cMD5StringToEncode), cPayload"
    }

    SendStringRaw(cPayload)
}


define_function SendQuery(integer iParam) {
    if (iPollSequenceEnabled[iParam]) {
        switch (iParam) {
            case GET_MODEL: SendString("'QID'")
            case GET_POWER: SendString("'Q$S'")
            case GET_INPUT: SendString("'QIN'")
            case GET_LAMP1: SendString(LAMP_1_QUERY_COMMANDS[iLamp1QueryCommand])
            case GET_LAMP2: SendString("'Q$L:2'")
            case GET_SHUTT: SendString("'QSH'")
            case GET_ASPECT: { SendString('QSE') }            //Get Aspect
            case GET_VOLUME: SendString("'QAV'")
        }
    }
}


define_function TimeOut() {
    cancel_wait 'CommsTimeOut'

    wait 300 'CommsTimeOut' {
        [vdvObject, DEVICE_COMMUNICATING] = false

        if (iCommMode == COMM_MODE_IP_DIRECT) {
            //uIPConnection.IsConnected = false
            NAVClientSocketClose(dvPort.PORT)
        }
    }
}


define_function SetPower(integer iParam) {
    switch (iParam) {
        case REQUIRED_POWER_ON: { SendString("'PON'") }
        case REQUIRED_POWER_OFF: { SendString("'POF'") }
    }
}


define_function SetInput(integer iParam) { SendString("'IIS:', INPUT_COMMANDS[iParam]") }

define_function SetVolume(sinteger siParam) { SendString("'AVL:', itoa(siParam)") }

define_function SetShutter(integer iParam) {
    switch (iRequiredShutter) {
        case REQUIRED_SHUTTER_OPEN: { SendString("'OSH:0'") }
        case REQUIRED_SHUTTER_CLOSED: { SendString("'OSH:1'") }
    }
}


define_function Process() {
    stack_var char cTemp[NAV_MAX_BUFFER]

    if (iSemaphore) {
        return
    }

    iSemaphore = true

    while (length_array(cRxBuffer) && NAVContains(cRxBuffer, COMM_MODE_DELIMITER[iCommMode])) {
        cTemp = remove_string(cRxBuffer, COMM_MODE_DELIMITER[iCommMode], 1)

        if (!length_array(cTemp)) {
            continue
        }

        NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'Parsing String From ', NAVConvertDPSToAscii(dvPort), '-[', cTemp, ']'")

        cTemp = NAVStripCharsFromRight(cTemp, 1)    //Remove delimiter

        select {
            active (NAVStartsWith(cTemp, 'NTCONTROL')): {
                //Connection Started
                cTemp = NAVStripCharsFromLeft(cTemp, 10);

                iSecureCommandRequired = atoi(remove_string(cTemp, ' ', 1));

                if (iSecureCommandRequired) {
                    cMD5RandomNumber = cTemp;
                    //if (len(password) > 0 && len(user_name) > 0) {
                        cMD5StringToEncode = "cUserName, ':', cPassword, ':', cMD5RandomNumber"
                    //}//else {
                        //sMD5StringToEncode = DEFAULT_USER_NAME + ":" + DEFAULT_PASSWORD + ":" + sMD5RandomNumber;
                    //}
                }

                iConnectionStarted = 1;
                iLoop = 0;
                Drive();
            }
            active (NAVStartsWith(cTemp, COMM_MODE_HEADER[iCommMode])): {
                remove_string(cTemp, COMM_MODE_HEADER[iCommMode], 1)

                if (NAVStartsWith(cTemp, 'ER')) {
                    iPollSequence = GET_MODEL
                    continue
                }

                switch (iPollSequence) {
                    case GET_POWER: {
                        switch (cTemp) {
                            case '0': { uProj.Display.PowerState.Actual = ACTUAL_POWER_OFF; if (iPollSequenceEnabled[GET_LAMP1]) iPollSequence = GET_LAMP1; }
                            case '1': { uProj.Display.PowerState.Actual = ACTUAL_WARMING; if (iPollSequenceEnabled[GET_LAMP1]) iPollSequence = GET_LAMP1; }
                            case '2': {
                                uProj.Display.PowerState.Actual = ACTUAL_POWER_ON

                                select {
                                    active (!iInputInitialized): { iPollSequence = GET_INPUT }
                                    active (!iShutterInitialized): { iPollSequence = GET_SHUTT }
                                    //active (!iVolumeInitialized): { iPollSequence = GET_VOLUME }
                                    //active (!iFreezeInitialized): { iPollSequence = GET_FREEZE }
                                    //active (!iAspectInitialized): { iPollSequence = GET_ASPECT }
                                    active (true): {
                                        if (iPollSequenceEnabled[GET_LAMP1]) { iPollSequence = GET_LAMP1 }
                                    }
                                }
                            }
                            case '3': { uProj.Display.PowerState.Actual = ACTUAL_COOLING; if (iPollSequenceEnabled[GET_LAMP1]) iPollSequence = GET_LAMP1; }
                        }
                    }
                    case GET_INPUT: {
                        select {
                            active (NAVContains(cTemp, "'RG1'")): { uProj.Display.Input.Actual = ACTUAL_INPUT_VGA_1; iPollSequence = GET_POWER; iInputInitialized = true }
                            active (NAVContains(cTemp, "'RG2'")): { uProj.Display.Input.Actual = ACTUAL_INPUT_RGB_1; iPollSequence = GET_POWER; iInputInitialized = true }
                            active (NAVContains(cTemp, "'VID'")): { uProj.Display.Input.Actual = ACTUAL_INPUT_VIDEO_1; iPollSequence = GET_POWER; iInputInitialized = true }
                            active (NAVContains(cTemp, "'SVD'")): { uProj.Display.Input.Actual = ACTUAL_INPUT_SVIDEO_1; iPollSequence = GET_POWER; iInputInitialized = true }
                            active (NAVContains(cTemp, "'DVI'")): { uProj.Display.Input.Actual = ACTUAL_INPUT_DVI_1; iPollSequence = GET_POWER; iInputInitialized = true }
                            active (NAVContains(cTemp, "'SDI'")): { uProj.Display.Input.Actual = ACTUAL_INPUT_SDI_1; iPollSequence = GET_POWER; iInputInitialized = true }
                            active (NAVContains(cTemp, "'HD1'")): { uProj.Display.Input.Actual = ACTUAL_INPUT_HDMI_1; iPollSequence = GET_POWER; iInputInitialized = true }
                            active (NAVContains(cTemp, "'DL1'")): { uProj.Display.Input.Actual = ACTUAL_INPUT_DIGITAL_LINK_1; iPollSequence = GET_POWER; iInputInitialized = true }
                        }
                    }
                    case GET_LAMP1: {
                        if (length_array(cTemp) == 4) {
                            stack_var integer iTemp

                            iTemp = atoi(cTemp)

                            if (iTemp != uProj.LampHours[1].Actual) {
                                uProj.LampHours[1].Actual = iTemp
                                send_string vdvObject, "'LAMPTIME-', itoa(uProj.LampHours[1].Actual)"
                            }

                            if (iPollSequenceEnabled[GET_LAMP2]) {
                                iPollSequence = GET_LAMP2;
                            }
                            else {
                                iPollSequence = GET_POWER;
                            }
                        }
                    }
                    case GET_LAMP2: {
                        if (length_array(cTemp) == 4) {
                            stack_var integer iTemp

                            iTemp = atoi(cTemp)

                            if (iTemp != uProj.LampHours[2].Actual) {
                                uProj.LampHours[2].Actual = iTemp
                                send_string vdvObject, "'LAMPTIME-', itoa(uProj.LampHours[2].Actual)"
                            }

                            iPollSequence = GET_POWER
                        }
                    }
                    case GET_SHUTT: {
                        switch (cTemp) {
                            case '0': { uProj.Display.VideoMute.Actual = ACTUAL_SHUTTER_OPEN; iPollSequence = GET_POWER; iShutterInitialized = true }
                            case '1': { uProj.Display.VideoMute.Actual = ACTUAL_SHUTTER_CLOSED; iPollSequence = GET_POWER; iShutterInitialized = true }
                        }
                    }
                    case GET_FREEZE: {
                        switch (cTemp) {
                            case '0': { iActualFreeze = ACTUAL_FREEZE_OFF; iPollSequence = GET_POWER; iFreezeInitialized = true }
                            case '1': { iActualFreeze = ACTUAL_FREEZE_ON; iPollSequence = GET_POWER; iFreezeInitialized = true }
                        }
                    }
                    case GET_ASPECT: {
                        switch (atoi(cTemp)) {
                            case 0: { iActualAspect = 1; iPollSequence = GET_POWER; iAspectInitialized = true }
                            case 5: { iActualAspect = 2; iPollSequence = GET_POWER; iAspectInitialized = true}
                            case 2: { iActualAspect = 3; iPollSequence = GET_POWER; iAspectInitialized = true}
                            case 1: { iActualAspect = 4; iPollSequence = GET_POWER; iAspectInitialized = true}
                            case 10: { iActualAspect = 6; iPollSequence = GET_POWER; iAspectInitialized = true}
                            case 9: { iActualAspect = 5; iPollSequence = GET_POWER; iAspectInitialized = true}
                            case 6: { iActualAspect = 7; iPollSequence = GET_POWER; iAspectInitialized = true }
                        }
                    }
                    case GET_VOLUME: {
                        siActualVolume = atoi(cTemp)
                        send_level vdvObject, 1, siActualVolume * 255 / 63
                        iVolumeInitialized = true
                        iPollSequence = GET_POWER
                    }
                    case GET_MODEL: {    //Model
                        select {
                            active (NAVContains(cTemp, 'RZ') > 0): { iPollSequenceEnabled[GET_LAMP1] = 0; iPollSequenceEnabled[GET_LAMP2] = 0; iPollSequence = GET_POWER; }
                            active (NAVContains(cTemp, 'MZ') > 0): { iPollSequenceEnabled[GET_LAMP1] = 0; iPollSequenceEnabled[GET_LAMP2] = 0; iPollSequence = GET_POWER; }
                            active (NAVContains(cTemp, 'RW') > 0): { iPollSequenceEnabled[GET_LAMP1] = 0; iPollSequenceEnabled[GET_LAMP2] = 0; iPollSequence = GET_POWER; }
                            active (NAVContains(cTemp, 'FRQ') > 0): { iPollSequenceEnabled[GET_LAMP1] = 0; iPollSequenceEnabled[GET_LAMP2] = 0; iPollSequence = GET_POWER; }
                            active (NAVContains(cTemp, 'FW') > 0): { iLamp1QueryCommand = 1; iPollSequenceEnabled[GET_LAMP2] = 0; iPollSequence = GET_POWER; }
                            active (NAVContains(cTemp, 'DX') > 0): { iLamp1QueryCommand = 1; iPollSequenceEnabled[GET_LAMP2] = 0; iPollSequence = GET_POWER; }
                        }
                    }
                }
            }
        }
    }

    iSemaphore = false
}


define_function integer CommModeIsIP(integer iCommMode) {
    return iCommMode == COMM_MODE_IP_DIRECT || iCommMode == COMM_MODE_IP_INDIRECT
}


define_function Drive() {
    if (!iConnectionStarted && CommModeIsIP(iCommMode)) {
        return;
    }

    if (iSecureCommandRequired && !length_array(cMD5StringToEncode) && CommModeIsIP(iCommMode)) {
        return;
    }

    if (!uIPConnection.IsConnected && CommModeIsIP(iCommMode)) {
        return;
    }

    iLoop++

    switch (iLoop) {
        case 1:
        case 6:
        case 11:
        case 16: { SendQuery(iPollSequence); return }
        case 21: { iLoop = 1; return }
        default: {
            if (iCommandLockOut) { return }
            if (iRequiredPower && (iRequiredPower == uProj.Display.PowerState.Actual)) { iRequiredPower = 0; return }
            if (iRequiredInput && (iRequiredInput == uProj.Display.Input.Actual)) { iRequiredInput = 0; return }
            if (iRequiredShutter && (iRequiredShutter == uProj.Display.VideoMute.Actual)) { iRequiredShutter = 0; return }
            if (iRequiredAspect && (iRequiredAspect == iActualAspect)) { iRequiredAspect = 0; return }
            if (iRequiredFreeze && (iRequiredFreeze == iActualFreeze)) { iRequiredFreeze = 0; return }

            if (iRequiredPower && (iRequiredPower != uProj.Display.PowerState.Actual) && (uProj.Display.PowerState.Actual != ACTUAL_WARMING) && (uProj.Display.PowerState.Actual != ACTUAL_COOLING) && [vdvObject, DEVICE_COMMUNICATING]) {
                iCommandBusy = true
                SetPower(iRequiredPower)
                iCommandLockOut = true
                wait 50 iCommandLockOut = false
                iPollSequence = GET_POWER
                return
            }

            if (iRequiredInput && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON) && (iRequiredInput != uProj.Display.Input.Actual) && [vdvObject, DEVICE_COMMUNICATING]) {
                iCommandBusy = true
                SetInput(iRequiredInput)
                iCommandLockOut = true
                wait 20 iCommandLockOut = false
                iPollSequence = GET_INPUT
                return
            }

            if (iRequiredShutter && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON) && (iRequiredShutter != uProj.Display.VideoMute.Actual) && [vdvObject, DEVICE_COMMUNICATING]) {
                iCommandBusy = true
                SetShutter(iRequiredShutter)
                iCommandLockOut = true
                wait 10 iCommandLockOut = false
                iPollSequence = GET_SHUTT
                return
            }

            if (iRequiredFreeze && (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON) && (iRequiredFreeze != iActualFreeze) && [vdvObject, DEVICE_COMMUNICATING]) {
                iCommandBusy = true
                //SetShutter(iRequiredShutter)
                iCommandLockOut = true
                wait 10 iCommandLockOut = false
                iPollSequence = GET_FREEZE
                return
            }

            if (iRequiredAspect && (uProj.Display.PowerState.Required == ACTUAL_POWER_ON) && (iRequiredAspect != iActualAspect) && [vdvObject, DEVICE_COMMUNICATING]) {
                switch (iRequiredAspect) {
                    case 1: { SendString('VSE:0') }    //Normal
                    case 2: { SendString('VSE:5') }    //Native
                    case 3: { SendString('VSE:2') }    //Wide
                    case 4: { SendString('VSE:1') }    //4x3
                    case 5: { SendString('VSE:9') }    //H-Fit
                    case 6: { SendString('VSE:10') }    //V-Fit
                    case 7: { SendString('VSE:6') }    //Full
                }

                iCommandLockOut = true
                wait 10 iCommandLockOut = false
                iPollSequence = GET_ASPECT;
                return;
            }

            if (iAutoImageRequired && (uProj.Display.PowerState.Required == ACTUAL_POWER_ON) && [vdvObject, DEVICE_COMMUNICATING]) {
                SendString('OAS'); iCommandLockout = true; wait 10 iCommandLockOut = false;    //Auto Image
                iAutoImageRequired = false
            }

            if ([vdvObject, MENU_FUNC]) { SendString('OMN') iCommandLockOut = true; wait 5 iCommandLockOut = false }
            if ([vdvObject, MENU_UP]) { SendString('OCU') iCommandLockOut = true; wait 5 iCommandLockOut = false }
            if ([vdvObject, MENU_DN]) { SendString('OCD') iCommandLockOut = true; wait 5 iCommandLockOut = false }
            if ([vdvObject, MENU_LT]) { SendString('OCL') iCommandLockOut = true; wait 5 iCommandLockOut = false }
            if ([vdvObject, MENU_RT]) { SendString('OCR') iCommandLockOut = true; wait 5 iCommandLockOut = false }
            if ([vdvObject, MENU_SELECT]) { SendString('OEN') iCommandLockOut = true; wait 5 iCommandLockOut = false }
            if ([vdvObject, MENU_CANCEL]) { SendString('OBK') iCommandLockOut = true; wait 5 iCommandLockOut = false }
            if ([vdvObject, MENU_DISPLAY]) { SendString('OOS') iCommandLockOut = true; wait 5 iCommandLockOut = false }
        }
    }
}


define_function MaintainIPConnection() {
    if (uIPConnection.IsConnected) {
        return
    }

    NAVClientSocketOpen(dvPort.PORT, uIPConnection.Address, uIPConnection.Port, IP_TCP)
}


(***********************************************************)
(*                STARTUP CODE GOES BELOW                  *)
(***********************************************************)
DEFINE_START {
    create_buffer dvPort, cRxBuffer

    uIPConnection.Port = DEFAULT_TCP_PORT
}

(***********************************************************)
(*                THE EVENTS GO BELOW                      *)
(***********************************************************)
DEFINE_EVENT

data_event[dvPort] {
    online: {
        if (data.device.number != 0) {
            NAVCommand(data.device, "'SET BAUD ', cBaudRate, ', N, 8, 1 485 DISABLE'")
            NAVCommand(data.device, "'B9MOFF'")
            NAVCommand(data.device, "'CHARD-0'")
            NAVCommand(data.device, "'CHARDM-0'")
            NAVCommand(data.device, "'HSOFF'")
        }

        if (data.device.number == 0) {
            uIPConnection.IsConnected = true
            // iCommMode = COMM_MODE_IP_DIRECT
        }

        NAVTimelineStart(TL_DRIVE, ltDrive, timeline_absolute, timeline_repeat)
    }
    string: {
        [vdvObject, DEVICE_COMMUNICATING] = true
        [vdvObject, DATA_INITIALIZED] = true

        TimeOut()

        NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'String From ', NAVConvertDPSToAscii(data.device), '-[', data.text, ']'")

        if (!iSemaphore) { Process() }
    }
    offline: {
        if (data.device.number == 0) {
            uIPConnection.IsConnected = false
            NAVClientSocketClose(data.device.port)

            // iCommMode = COMM_MODE_SERIAL

            // NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'PANASONIC_PROJECTOR_IP_OFFLINE<', NAVStringSurroundWith(NAVDeviceToString(dvPortIP), '[', ']'), '>'")
        }
    }
    onerror: {
        if (data.device.number == 0) {
            uIPConnection.IsConnected = false
            //NAVClientSocketClose(data.device.port)

            // iCommMode = COMM_MODE_SERIAL

            // NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'PANASONIC_PROJECTOR_IP_ONERROR<', NAVStringSurroundWith(NAVDeviceToString(dvPortIP), '[', ']'), '>'")
        }
    }
}


data_event[vdvObject] {
    online: {
        NAVCommand(data.device, "'PROPERTY-RMS_MONITOR_ASSET_PROPERTY,MONITOR_ASSET_DESCRIPTION,Video Projector'")
        NAVCommand(data.device, "'PROPERTY-RMS_MONITOR_ASSET_PROPERTY,MONITOR_ASSET_MANUFACTURER_URL,www.panasonic.com'")
        NAVCommand(data.device, "'PROPERTY-RMS_MONITOR_ASSET_PROPERTY,MONITOR_ASSET_MANUFACTURER_NAME,PANASONIC'")
    }
    command: {
        stack_var char cCmdHeader[NAV_MAX_CHARS]
        stack_var char cCmdParam[2][NAV_MAX_CHARS]

        NAVErrorLog(NAV_LOG_LEVEL_DEBUG, NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_COMMAND_FROM, data.device, data.text))

        cCmdHeader = DuetParseCmdHeader(data.text)
        cCmdParam[1] = DuetParseCmdParam(data.text)
        cCmdParam[2] = DuetParseCmdParam(data.text)

        switch (cCmdHeader) {
            case 'PROPERTY': {
                switch (cCmdParam[1]) {
                    case 'IP_ADDRESS': {
                        uIPConnection.Address = cCmdParam[2]
                        NAVTimelineStart(TL_IP_CLIENT_CHECK, ltIPClientCheck, TIMELINE_ABSOLUTE, TIMELINE_REPEAT)
                    }
                    case 'IP_PORT': {
                        uIPConnection.Port = atoi(cCmdParam[2])
                    }
                    case 'COMM_MODE': {
                        switch (cCmdParam[2]) {
                            case 'SERIAL': {
                                iCommMode = COMM_MODE_SERIAL
                            }
                            case 'IP_DIRECT': {
                                iCommMode = COMM_MODE_IP_DIRECT
                            }
                            case 'IP_INDIRECT': {
                                iCommMode = COMM_MODE_IP_INDIRECT
                            }
                        }
                    }
                    case 'ID': {
                        cID = format('%02d', atoi(cCmdParam[2]))
                    }
                    case 'BAUD_RATE': {
                        cBaudRate = cCmdParam[2]

                        if ((iCommMode == COMM_MODE_SERIAL) && device_id(dvPort)) {
                            send_command dvPort, "'SET BAUD ', cBaudRate, ', N, 8, 1 485 DISABLE'"
                        }
                    }
                    case 'USER_NAME': {
                        cUserName = cCmdParam[2]

                        if (length_array(cMD5RandomNumber)) {
                            cMD5StringToEncode = "cUserName, ':', cPassword, ':', cMD5RandomNumber"
                        }
                    }
                    case 'PASSWORD': {
                        cPassword = cCmdParam[2]

                        if (length_array(cMD5RandomNumber)) {
                            cMD5StringToEncode = "cUserName, ':', cPassword, ':', cMD5RandomNumber"
                        }
                    }
                }
            }
            case 'PASSTHRU': { SendString(cCmdParam[1]) }
            case 'POWER': {
                switch (cCmdParam[1]) {
                    case 'ON': { iRequiredPower = REQUIRED_POWER_ON; Drive() }
                    case 'OFF': { iRequiredPower = REQUIRED_POWER_OFF; iRequiredInput = 0; Drive() }
                }
            }
            case 'MUTE': {
                if (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON) {
                    switch (cCmdParam[1]) {
                        case 'ON': { iRequiredShutter = REQUIRED_SHUTTER_CLOSED; Drive() }
                        case 'OFF': { iRequiredShutter = REQUIRED_SHUTTER_OPEN; Drive() }
                    }
                }
            }
            case 'ADJUST': {
                if (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON) {
                    iAutoImageRequired = true
                }
            }
            case 'ASPECT': {
                if (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON) {
                    switch (cCmdParam[1]) {
                        case 'NORMAL': { iRequiredAspect = 1; Drive() }
                        case 'NATIVE': { iRequiredAspect = 2; Drive() }
                        case 'WIDE': { iRequiredAspect = 3; Drive() }
                        case '4x3': { iRequiredAspect = 4; Drive() }
                        case 'H_FIT': { iRequiredAspect = 5; Drive() }
                        case 'V_FIT': { iRequiredAspect = 6; Drive() }
                        case 'FULL': { iRequiredAspect = 7; Drive() }
                    }
                }
            }
            case 'VOLUME': {
                switch (cCmdParam[1]) {
                    case 'ABS': {
                        SetVolume(atoi(cCmdParam[2]))
                        iPollSequence = GET_VOLUME
                    }
                    default: {
                        SetVolume(atoi(cCmdParam[1]) * 63 / 255)
                        iPollSequence = GET_VOLUME
                    }
                }
            }
            case 'INPUT': {
                switch (cCmdParam[1]) {
                    case 'VGA': {
                        switch (cCmdParam[2]) {
                            case '1': { iRequiredPower = REQUIRED_POWER_ON; iRequiredInput = REQUIRED_INPUT_VGA_1; Drive() }
                        }
                    }
                    case 'RGB': {
                        switch (cCmdParam[2]) {
                            case '1': { iRequiredPower = REQUIRED_POWER_ON; iRequiredInput = REQUIRED_INPUT_RGB_1; Drive() }
                        }
                    }
                    case 'HDMI': {
                        switch (cCmdParam[2]) {
                            case '1': { iRequiredPower = REQUIRED_POWER_ON; iRequiredInput = REQUIRED_INPUT_HDMI_1; Drive() }
                        }
                    }
                    case 'DVI': {
                        switch (cCmdParam[2]) {
                            case '1': { iRequiredPower = REQUIRED_POWER_ON; iRequiredInput = REQUIRED_INPUT_DVI_1; Drive() }
                        }
                    }
                    case 'DIGITAL_LINK': {
                        switch (cCmdParam[2]) {
                            case '1': { iRequiredPower = REQUIRED_POWER_ON; iRequiredInput = REQUIRED_INPUT_DIGITAL_LINK_1; Drive() }
                        }
                    }
                    case 'S-VIDEO': {
                        switch (cCmdParam[2]) {
                            case '1': { iRequiredPower = REQUIRED_POWER_ON; iRequiredInput = REQUIRED_INPUT_SVIDEO_1; Drive() }
                        }
                    }
                    case 'COMPOSITE': {
                        switch (cCmdParam[2]) {
                            case '1': { iRequiredPower = REQUIRED_POWER_ON; iRequiredInput = REQUIRED_INPUT_VIDEO_1; Drive() }
                        }
                    }
                    case 'SDI': {
                        switch (cCmdParam[2]) {
                            case '1': { iRequiredPower = REQUIRED_POWER_ON; iRequiredInput = REQUIRED_INPUT_SDI_1; Drive() }
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
                if (iRequiredPower) {
                    switch (iRequiredPower) {
                        case REQUIRED_POWER_ON: { iRequiredPower = REQUIRED_POWER_OFF; iRequiredInput = 0; Drive() }
                        case REQUIRED_POWER_OFF: { iRequiredPower = REQUIRED_POWER_ON; Drive() }
                    }
                }
                else {
                    switch (uProj.Display.PowerState.Actual) {
                        case ACTUAL_POWER_ON: { iRequiredPower = REQUIRED_POWER_OFF; iRequiredInput = 0; Drive() }
                        case ACTUAL_POWER_OFF: { iRequiredPower = REQUIRED_POWER_ON; Drive() }
                    }
                }
            }
            case PWR_ON: { iRequiredPower = REQUIRED_POWER_ON; Drive() }
            case PWR_OFF: { iRequiredPower = REQUIRED_POWER_OFF; iRequiredInput = 0; Drive() }
            case PIC_MUTE: {
                if (iRequiredShutter) {
                    switch (iRequiredShutter) {
                        case REQUIRED_SHUTTER_CLOSED: { iRequiredPower = REQUIRED_SHUTTER_OPEN; Drive() }
                        case REQUIRED_SHUTTER_OPEN: { iRequiredPower = REQUIRED_SHUTTER_CLOSED; Drive() }
                    }
                }
                else {
                    switch (uProj.Display.VideoMute.Actual) {
                        case ACTUAL_SHUTTER_CLOSED: { iRequiredPower = REQUIRED_SHUTTER_OPEN; Drive() }
                        case ACTUAL_SHUTTER_OPEN: { iRequiredPower = REQUIRED_SHUTTER_CLOSED; Drive() }
                    }
                }
            }
            case PIC_MUTE_ON: {
                if (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON) {
                    iRequiredShutter = REQUIRED_SHUTTER_CLOSED; Drive()
                }
            }
        }
    }
    off: {
        switch (channel.channel) {
            case PIC_MUTE_ON: {
                if (uProj.Display.PowerState.Actual == ACTUAL_POWER_ON) {
                    iRequiredShutter = REQUIRED_SHUTTER_OPEN; Drive()
                }
            }
        }
    }
}


timeline_event[TL_DRIVE] { Drive() }

timeline_event[TL_IP_CLIENT_CHECK] { MaintainIPConnection() }

timeline_event[TL_NAV_FEEDBACK] {
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

