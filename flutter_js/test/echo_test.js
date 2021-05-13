(async function() {
    FlutterJS.dispatch(100);
    async function invoke(channel, args) {
        console.log(4);
        const result = await FlutterJS.callNative(channel, args);
        console.log(5);
        console.log(`${channel}(${JSON.stringify(args)}) => ${JSON.stringify(result)}`);
    }
    async function aa() {
        console.log(2);
    }
    console.log(1);
    await aa();
    console.log(3);
    await invoke('echo', 'Ping?');
    console.log(6);
    return 'Hello World!';
}());