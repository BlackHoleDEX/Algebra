
function expXg4(x, g, gHighestDegree) {
    let closestValue;
    let xdg = Math.floor(x / g);
    switch (xdg) {
        case 0: closestValue = BigInt("100000000000000000000"); break;
        case 1: closestValue = BigInt("271828182845904523536"); break;
        case 2: closestValue = BigInt("738905609893065022723"); break;
        case 3: closestValue = BigInt("2008553692318766774092"); break;
        case 4: closestValue = BigInt("5459815003314423907811"); break;
        default: closestValue = BigInt("14841315910257660342111"); break;
    }

    x = x % g;
    let bg = BigInt(g);
    let bx = BigInt(x);

    if (bx >= bg / 2n) {
        bx -= bg / 2n;
        closestValue = (closestValue * BigInt("164872127070012814684")) / BigInt(1e20);
    }

    let xLowestDegree = bx;
    let res = BigInt(gHighestDegree);
    let gHD = BigInt(gHighestDegree);

    gHD /= bg; // g**3
    res += xLowestDegree * gHD;

    gHD /= bg; // g**2
    xLowestDegree *= bx;
    res += (xLowestDegree * gHD) / 2n;

    gHD /= bg; // g
    xLowestDegree *= bx;
    res += (xLowestDegree * bg * 4n + xLowestDegree * bx) / 24n;

    res = (res * closestValue) / BigInt(1e20);
    return res;
}

function sigmoid(x, g, alpha, beta) {
    x = BigInt(x);
    g = BigInt(g);
    alpha = BigInt(alpha);
    beta = BigInt(beta);

    if (x > beta) {
        let diff = x - beta;
        if (diff >= 6n * g) return alpha;
        let g4 = g ** 4n;
        let ex = expXg4(Number(diff), Number(g), g4);
        return (alpha * ex) / (g4 + ex);
    } else {
        let diff = beta - x;
        if (diff >= 6n * g) return 0n;
        let g4 = g ** 4n;
        let ex = g4 + expXg4(Number(diff), Number(g), g4);
        return (alpha * g4) / ex;
    }
}

function getFee(volatility) {
    let normalizedVol = Math.floor(volatility / 15);

    // updated config
    let alpha1 = 4500;
    let alpha2 = 15000;
    let beta1 = 1667;
    let beta2 = 6000;
    let gamma1 = 400;
    let gamma2 = 500;
    let baseFee = 500;

    let s1 = sigmoid(normalizedVol, gamma1, alpha1, beta1);
    let s2 = sigmoid(normalizedVol, gamma2, alpha2, beta2);

    console.log("Normalized Volatility:", normalizedVol);
    console.log("Sigmoid 1:", s1.toString());
    console.log("Sigmoid 2:", s2.toString());
    console.log("Base Fee:", baseFee);

    let totalFee = BigInt(baseFee) + s1 + s2;
    console.log("Total Fee (hundredths of a bip):", totalFee.toString());
    console.log("Total Fee (%):", (Number(totalFee) / 10000).toFixed(4) + "%");
}

getFee(14565);
