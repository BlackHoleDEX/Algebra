const tronbox = require("../../tronbox-config");
const pos_manager_artifact = require("../../build/contracts/NonfungiblePositionManager.json");
const tronWeb = tronbox.tronWeb.nile

async function main() {
    const contractAddress = "TCeHRDW5RoFLbzvgTcyQgTBDrzYdQGELnM";
    let contract = await tronWeb.contract(pos_manager_artifact.abi,contractAddress);
    let data = [tronWeb.address.toHex("TMTYAUSQVUe5x8rwDYwzwNJQSWUCQtV7Uo"),
      tronWeb.address.toHex("TYsbWxNnyTgsZaTFaue9hqpxkU3Fkco94a"),
      "410000000000000000000000000000000000000000",
      -600,
      600,
      100000,
      100000,
      0,
      0,
      tronWeb.address.toHex("TGq5GWxruUu47FaTcHLiX8oJGNtD8aRcoV"),
      1737207400
    ]
    console.log(data)
    await contract.mint(data).send();
    console.log(
      `done`
    );
}

main().then(() => {
    process.exit(0)
});