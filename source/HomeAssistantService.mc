//-----------------------------------------------------------------------------------
//
// Distributed under MIT Licence
//   See https://github.com/house-of-abbey/GarminHomeAssistant/blob/main/LICENSE.
//
//-----------------------------------------------------------------------------------
//
// GarminHomeAssistant is a Garmin IQ application written in Monkey C and routinely
// tested on a Venu 2 device. The source code is provided at:
//            https://github.com/house-of-abbey/GarminHomeAssistant.
//
// P A Abbey & J D Abbey & Someone0nEarth, 19 November 2023
//
//
// Description:
//
// Calling a Home Assistant Service.
//
//-----------------------------------------------------------------------------------

using Toybox.Lang;
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application.Properties;

class HomeAssistantService {
    private var strNoPhone          = WatchUi.loadResource($.Rez.Strings.NoPhone);
    private var strNoInternet       = WatchUi.loadResource($.Rez.Strings.NoInternet);
    private var strNoResponse       = WatchUi.loadResource($.Rez.Strings.NoResponse);
    private var strNoJson            = WatchUi.loadResource($.Rez.Strings.NoJson);
    private var strApiFlood         = WatchUi.loadResource($.Rez.Strings.ApiFlood);
    private var strApiUrlNotFound   = WatchUi.loadResource($.Rez.Strings.ApiUrlNotFound);
    private var strUnhandledHttpErr = WatchUi.loadResource($.Rez.Strings.UnhandledHttpErr);

    private var mApiKey as Lang.String;

    function initialize() {
        mApiKey = Properties.getValue("api_key");
    }

    // Callback function after completing the POST request to call a service.
    //
    function onReturnCall(responseCode as Lang.Number, data as Null or Lang.Dictionary or Lang.String, context as Lang.Object) as Void {
        var identifier = context as Lang.String;
        if (Globals.scDebug) {
            System.println("HomeAssistantService onReturnCall() Response Code: " + responseCode);
            System.println("HomeAssistantService onReturnCall() Response Data: " + data);
        }

        switch (responseCode) {
            case Communications.BLE_HOST_TIMEOUT:
            case Communications.BLE_CONNECTION_UNAVAILABLE:
                if (Globals.scDebug) {
                    System.println("HomeAssistantService onReturnCall() Response Code: BLE_HOST_TIMEOUT or BLE_CONNECTION_UNAVAILABLE, Bluetooth connection severed.");
                }
                ErrorView.show(strNoPhone + ".");
                break;

            case Communications.BLE_QUEUE_FULL:
                if (Globals.scDebug) {
                    System.println("HomeAssistantService onReturnCall() Response Code: BLE_QUEUE_FULL, API calls too rapid.");
                }
                ErrorView.show(strApiFlood);
                break;

            case Communications.NETWORK_REQUEST_TIMED_OUT:
                if (Globals.scDebug) {
                    System.println("HomeAssistantService onReturnCall() Response Code: NETWORK_REQUEST_TIMED_OUT, check Internet connection.");
                }
                ErrorView.show(strNoResponse);
                break;

            case Communications.NETWORK_RESPONSE_OUT_OF_MEMORY:
                if (Globals.scDebug) {
                    System.println("HomeAssistantService onReturnCall() Response Code: NETWORK_RESPONSE_OUT_OF_MEMORY, are we going too fast?");
                }
                // Ignore and see if we can carry on
                break;
            case Communications.INVALID_HTTP_BODY_IN_NETWORK_RESPONSE:
                if (Globals.scDebug) {
                    System.println("HomeAssistantService onReturnCall() Response Code: INVALID_HTTP_BODY_IN_NETWORK_RESPONSE, check JSON is returned.");
                }
                ErrorView.show(strNoJson);
                break;

            case 404:
                if (Globals.scDebug) {
                    System.println("HomeAssistantService onReturnCall() Response Code: 404, page not found. Check API URL setting.");
                }
                ErrorView.show(strApiUrlNotFound);
                break;

            case 200:
                if (Globals.scDebug) {
                    System.println("HomeAssistantService onReturnCall(): Service executed.");
                }
                var d     = data as Lang.Array;
                var toast = "Executed";
                for(var i = 0; i < d.size(); i++) {
                    if ((d[i].get("entity_id") as Lang.String).equals(identifier)) {
                        toast = (d[i].get("attributes") as Lang.Dictionary).get("friendly_name") as Lang.String;
                    }
                }
                if (WatchUi has :showToast) {
                    WatchUi.showToast(toast, null);
                } else {
                    new Alert({
                        :timeout => Globals.scAlertTimeout,
                        :font    => Graphics.FONT_MEDIUM,
                        :text    => toast,
                        :fgcolor => Graphics.COLOR_WHITE,
                        :bgcolor => Graphics.COLOR_BLACK
                    }).pushView(WatchUi.SLIDE_IMMEDIATE);
                }
                break;

            default:
                if (Globals.scDebug) {
                    System.println("HomeAssistantService onReturnCall(): Unhandled HTTP response code = " + responseCode);
                }
                ErrorView.show(strUnhandledHttpErr + responseCode);
        }
    }

    function call(identifier as Lang.String, service as Lang.String) as Void {
        var options = {
            :method  => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => {
                "Content-Type"  => Communications.REQUEST_CONTENT_TYPE_JSON,
                "Authorization" => "Bearer " + mApiKey
            },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
            :context      => identifier
        };
        if (! System.getDeviceSettings().phoneConnected) {
            if (Globals.scDebug) {
                System.println("HomeAssistantService call(): No Phone connection, skipping API call.");
            }
            ErrorView.show(strNoPhone + ".");
        } else if (! System.getDeviceSettings().connectionAvailable) {
            if (Globals.scDebug) {
                System.println("HomeAssistantService call(): No Internet connection, skipping API call.");
            }
            ErrorView.show(strNoInternet + ".");
        } else {
            // Can't use null for substring() parameters due to API version level.
            var url = (Properties.getValue("api_url") as Lang.String) + "/services/" + service.substring(0, service.find(".")) + "/" + service.substring(service.find(".")+1, service.length());
            if (Globals.scDebug) {
                System.println("HomeAssistantService call() URL=" + url);
                System.println("HomeAssistantService call() service=" + service);
            }
            Communications.makeWebRequest(
                url,
                {
                    "entity_id" => identifier
                },
                options,
                method(:onReturnCall)
            );
            if (Attention has :vibrate) {
                Attention.vibrate([
                    new Attention.VibeProfile(50, 100), // On  for 100ms
                    new Attention.VibeProfile( 0, 100), // Off for 100ms
                    new Attention.VibeProfile(50, 100)  // On  for 100ms
                ]);
            }
        }
    }

}
