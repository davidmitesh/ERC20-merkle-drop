// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;
import "./merkle-drop.sol";

/// @title MerkleDropFactory
/// @notice A factory contract to deploy ERC20 token airdrop claimable by members of a merkle tree
/// @author Mitesh Pandey <contact@ david.mitesh@gmail.com>
contract MerkleDropFactory {
    /// @notice this pattern is implemented in order to make the CRUD operations(if implemented) more efficient
    //---------------------------------
    struct MerkleDropStruct {
        string name;
        //other relevent data related to the merkle drop can be kept

        uint256 listPointer; //This will point to the index on the allDrops array
    }

    /// @notice Mapping of merkledrop instance address to the Merkledrop struct
    mapping(address => MerkleDropStruct) public addressToDropMapping;

    /// @notice keeping all the records of the created instances of merkle drops
    address[] public allDrops;

    //----------------------------------------

    /// ============ Events ============

    /// @notice Emitted after a AirDropToken contract is created
    /// @param instance address of the Airdrop contract
    event AirdropCreated(address indexed instance);

    /// @notice Allows creating a new airdrop contract by anyone with the desired ERC20 token
    /// @param _name name of the airdrop token contract
    /// @param _token ERC20 token address to be used in the airdrop contract
    /// @param @param _merkleRoot of claimees
    function createAirDrop(
        string memory _name,
        address _token,
        bytes32 _merkleRoot
    ) external returns (address) {
        require(
            _token != address(0),
            "zero address shouldn't be used as the airdrop token address"
        );
        address newInstance = address(new MerkleDrop(_merkleRoot, _token));
        addressToDropMapping[newInstance].name = _name;
        allDrops.push(newInstance);
        addressToDropMapping[newInstance].listPointer = allDrops.length - 1;
        emit AirdropCreated(newInstance);
        return newInstance;
    }
}
