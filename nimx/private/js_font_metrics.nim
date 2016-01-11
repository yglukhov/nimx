# Idea borrowed from from https://github.com/Pomax/fontmetrics.js

proc nimx_calculateFontMetricsInCanvas*(ctx: ref RootObj, fontFamily: cstring, fontSize: int): ref RootObj {.exportc.} =
    {.emit: """
    var textstring = "Hl@¿Éq";

    `result` = `ctx`.measureText(textstring);
    var canvas = document.createElement("canvas");
    var padding = 100;
    canvas.width = `result`.width + padding;
    canvas.height = 3*`fontSize`;
    canvas.style.opacity = 1;
//    canvas.style.fontFamily = `fontFamily`;
//    canvas.style.fontSize = `fontSize`;
    var ctx = canvas.getContext("2d");
    ctx.font = `fontSize` + "px " + `fontFamily`;

    var w = canvas.width,
        h = canvas.height,
        baseline = h/2;

    // Set all canvas pixeldata values to 255, with all the content
    // data being 0. This lets us scan for data[i] != 255.
    ctx.fillStyle = "white";
    ctx.fillRect(-1, -1, w+2, h+2);
    ctx.fillStyle = "black";
    ctx.fillText(textstring, padding/2, baseline);
    var pixelData = ctx.getImageData(0, 0, w, h).data;

    // canvas pixel data is w*4 by h*4, because R, G, B and A are separate,
    // consecutive values in the array, rather than stored as 32 bit ints.
    var i = 0,
        w4 = w * 4,
        len = pixelData.length;

    // Finding the ascent uses a normal, forward scanline
    while (++i < len && pixelData[i] === 255) {}
    var ascent = (i/w4)|0;

    // Finding the descent uses a reverse scanline
    i = len - 1;
    while (--i > 0 && pixelData[i] === 255) {}
    var descent = (i/w4)|0;

    `result`.ascent = (baseline - ascent);
    `result`.descent = (descent - baseline);
    `result`.height = 1+(descent - ascent);
    """.}
