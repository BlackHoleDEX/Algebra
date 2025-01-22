const tronbox = require("../../tronbox-config");
const swapRouterArtifact = require("../../build/contracts/SwapRouter.json");
const tronWeb = tronbox.tronWeb.nile

async function main() {
    const contractAddress = "TGdCHU8MRZ2xdp2hqBvrJMUTfJ6TQJbns3";
    let contract = await tronWeb.contract(swapRouterArtifact.abi,contractAddress);
    let data = [
      tronWeb.address.toHex("TMTYAUSQVUe5x8rwDYwzwNJQSWUCQtV7Uo"),
      tronWeb.address.toHex("TYsbWxNnyTgsZaTFaue9hqpxkU3Fkco94a"),
      "410000000000000000000000000000000000000000",
      tronWeb.address.toHex("TGq5GWxruUu47FaTcHLiX8oJGNtD8aRcoV"),
      1737433548,
      1000,
      0,
      0
    ]
    await contract.exactInputSingle(data).send();
    console.log(
      `done`
    );
}

main().then(() => {
    process.exit(0)
});