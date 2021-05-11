/**
 * Hold request callbacks
 */
const __flutter_js_extension_http_client__requests__ = {};
/**
 * Request id incremental
 */
let __flutter_js_extension_http_client__request_id__ = 0;
/**
 * Callback for dart to invoke when request finishs.
 * @param requestId request id the incoming response is associated to.
 * @param responseJson response represented in json string format.
 */
function __flutter_js_extension_http_client__callback__(requestId: string, responseJson: string): void {
  __flutter_js_extension_http_client__requests__[requestId](responseJson);
}
class AbortController {
  requestId: any;
  constructor() {
  }

  abort():void {
    if(this.requestId === undefined) {
        throw 'No request is attached to this controller.';
    }
    FlutterJS.sendMessage('http_client::abort', {id: this.requestId});
  }
}
FlutterJS.send = async function (httpOptions, clientOptions, abortController?): Promise<FlutterJSExtensionResponse> {
  const requestId = __flutter_js_extension_http_client__request_id__++;
  const _httpOptions: FlutterJSExtensionHttpOptions = typeof httpOptions === 'string' ? {url: httpOptions} : httpOptions;
  if(clientOptions == null) {
    clientOptions = {};
  } else {
    if(clientOptions instanceof AbortController) {
      abortController = clientOptions;
      clientOptions = {};
    }
  }

  if(abortController != null) {
    abortController.requestId = requestId;
  }
  const promise = new Promise<FlutterJSExtensionResponse>((resolve) => {
    __flutter_js_extension_http_client__requests__[requestId] = function (response: FlutterJSExtensionResponse) {
      delete __flutter_js_extension_http_client__requests__[requestId];
      console.log(`console:${JSON.stringify(response)}`);
      resolve(response);
    };
  });
  FlutterJS.sendMessage("http_client::send", { id: requestId, httpOptions: _httpOptions, clientOptions });
  return promise;
};
