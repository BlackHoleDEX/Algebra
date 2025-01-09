const { ethers  } = require('hardhat');

const { permissionRegistryAbi, permissionsRegistryAddress } = require('./gaugeConstants/permissions-registry')



async function main () {
    accounts = await ethers.getSigners();
    owner = accounts[0]
    const adminAddress = owner.address;

    const permissionRegistryContract = await ethers.getContractAt(permissionRegistryAbi, permissionsRegistryAddress);
    const permissionRegistryContractRoles = await permissionRegistryContract.roles();
    // console.log("permissionRegistryContractRoles ", permissionRegistryContractRoles);
    console.log("permissionRegistryContractRoles ", permissionRegistryContractRoles);

    const permissionRegistryRolesInStringFormat = await permissionRegistryContract.rolesToString();
    
    // for(const p of permissionRegistryContractRoles){
    //     const permissionRegistryContractRoles = await permissionRegistryContract.rolesToString();
    //     console.log("permissionRegistryContractRoles ", permissionRegistryContractRoles);
    // }
    await Promise.all(
        permissionRegistryRolesInStringFormat.map(async (element) => {
            try {
                console.log('Role in string format:', element);
    
                const setRoleTx = await permissionRegistryContract.setRoleFor(adminAddress, element, {
                    gasLimit: 21000000
                });
                await setRoleTx.wait();
                console.log('SetRole transaction:', setRoleTx);
            } catch (err) {
                console.log('Error in this part:', err);
            }
        })
    );
    
    await Promise.all(
        permissionRegistryContractRoles.map(async (element) => {
            const hasRole = await permissionRegistryContract.hasRole(element, adminAddress);
            console.log('Has role for role:', element, 'and for address:', adminAddress, hasRole);
        })
    );
    

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});