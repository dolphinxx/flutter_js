__nativeCallbacks__ = {};
__nativeCallbacksIncrement__ = 0;
async function callNative(channelName, args) {
    const callbackId = __nativeCallbacksIncrement__++;
    const promise = new Promise((resolve) => {
        __nativeCallbacks__[callbackId] = function() {
            delete __nativeCallbacks__[callbackId];
            console.log(`console:${JSON.stringify(arguments)}`);
            resolve(...arguments);
        };
    });
    sendMessage(channelName, {"message": JSON.stringify(args), "callback": callbackId});
    return promise;
}

