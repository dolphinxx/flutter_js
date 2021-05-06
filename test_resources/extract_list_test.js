(async function() {
    const html = await callNative('loadFile', 'html/catalog.html');
    const baseUrl = 'https://www.shouda88.com/151282/';
    const catalog = [...html.matchAll(/<dd><a href="(?<href>[^"]+)">(?<name>[^<]+)<\/a><\/dd>/g)];
    const idPattern = /(\d+)\.html/;
    return catalog.map(_ => ({id:_.groups.href.match(idPattern)[1], name:_.groups.name, url: new URL(_.groups.href, baseUrl).toString()}))
}());