(async function() {
    var a = 1;
    var b = 2;
    var c = await callNative('add', [a,b]);
    console.log(`console:${c}`);
    c = await callNative('time', [b, c]);
    console.log(`console:${c}`);
    c = await callNative('add', [b, c]);
    console.log(`console:${c}`);
    c = await callNative('time', [b, c]);
    console.log(`console:${c}`);
    c = await callNative('getStr', `I have ${c} `);
    console.log(`console:${c}`);
    return c + '.';
}());