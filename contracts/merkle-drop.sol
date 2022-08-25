// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// ============ Imports ============

import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; //  ERC20
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol"; // OZ: MerkleProof
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol"; //for verifying signatures

/// @title MerkleDrop
/// @notice ERC20 tokens claimable by members of a merkle tree
/// @author Mitesh Pandey <contact@davidmitesh@gmail.com>
contract MerkleDrop {
    /// ============ Immutable storage ============
    /// @notice ERC20 token address that will be airdropped through this contract instance
    address public immutable airdropToken;
    /// @notice ERC20-claimee inclusion root
    bytes32 public immutable merkleRoot;

    /// ============ Mutable storage ============

    /// @notice keeping the sign count in order to prevent signature replay attacks, before signing, this number should be included in signature as well
    uint256 public signCountNumber;

    /// @notice Mapping of addresses who have claimed tokens
    mapping(address => bool) public hasClaimed;

    /// @notice Mapping of addresses to the amount of tokens they hold after claiming
    mapping(address => uint256) public remainingTokens;

    /// ============ Errors ============

    /// @notice Thrown if address has already claimed
    error AlreadyClaimed();
    /// @notice Thrown if address/amount are not part of Merkle tree
    error NotInMerkle();
    /// @notice Thrown if address hasnot claimed token but tries to withdraw
    error NotClaimed();
    /// @notice Thrown if address doesnot have enough tokens to withdraw
    error InsufficientTokens();

    /// ============ Constructor ============

    /// @notice Creates a new MerkleDrop contract for a specific ERC20 token
    /// @param _merkleRoot of claimees
    constructor(bytes32 _merkleRoot, address _token) {
        airdropToken = _token; //setting the airdrop erc20 token
        merkleRoot = _merkleRoot; // Update root
    }

    /// ============ Events ============

    /// @notice Emitted after a successful token claim
    /// @param to recipient of claim
    /// @param amount of tokens claimed
    event Claim(address indexed to, uint256 amount);

    /// @notice Emitted after a successful token claim
    /// @param to recipient of claim
    /// @param amount of tokens claimed
    event Withdraw(address indexed to, uint256 amount);

    /// ============ Functions ============

    /// @notice Allows claiming tokens if address is part of merkle tree
    /// @param to address of claimee
    /// @param amount of tokens owed to claimee
    /// @param proof merkle proof to prove address and amount are in tree
    function claim(
        address to,
        uint256 amount,
        bytes32[] calldata proof
    ) external {
        // Throw if address has already claimed tokens
        if (hasClaimed[to]) revert AlreadyClaimed();

        // Verify merkle proof, or revert if not in tree
        bytes32 leaf = keccak256(abi.encodePacked(to, amount));
        bool isValidLeaf = MerkleProof.verify(proof, merkleRoot, leaf);
        if (!isValidLeaf) revert NotInMerkle();

        // Set address to claimed
        hasClaimed[to] = true;
        remainingTokens[to] = amount;

        // Emit claim event
        emit Claim(to, amount);
    }

    /// @notice Allows withdrawing of tokens for the users who have already claimed
    /// @param amount of tokens to withdraw
    function withdraw(uint256 amount) external {
        // Throw if address has already claimed tokens
        if (!hasClaimed[msg.sender]) revert NotClaimed();

        //Throw if address has insufficient tokens to withdraw
        if (remainingTokens[msg.sender] < amount) revert InsufficientTokens();

        remainingTokens[msg.sender] -= amount;

        require(
            IERC20(airdropToken).transfer(msg.sender, amount),
            "MerkleDrop: Transfer failed."
        );

        emit Withdraw(msg.sender, amount);
    }

    /// @notice Allows withdrawing of tokens by anybody if they have the signature from the valid user
    /// @param amount of tokens to withdraw
    /// @param signature A valid signature need to be passed from the valid user to transfer tokens on their behalf
    /// @param to address to send the tokens
    function withdrawWithSignature(
        uint256 amount,
        bytes calldata signature,
        address to
    ) external {
        require(
            to != address(0),
            "sender address as zero address not applicable"
        ); //user may lost tokens in such manner
        address signer = _returnSigner(
            _hash(to, amount, signCountNumber),
            signature
        );
        // Throw if address has already claimed tokens
        if (!hasClaimed[signer]) revert NotClaimed();

        //Throw if address has insufficient tokens to withdraw
        if (remainingTokens[signer] < amount) revert InsufficientTokens();

        remainingTokens[signer] -= amount;

        require(
            IERC20(airdropToken).transfer(to, amount),
            "MerkleDrop: Transfer failed."
        );

        signCountNumber += 1;

        emit Withdraw(to, amount);
    }

    function _hash(
        address account,
        uint256 amount,
        uint256 _signCountNumber
    ) internal pure returns (bytes32) {
        return
            ECDSA.toEthSignedMessageHash(
                keccak256(abi.encodePacked(account, amount, _signCountNumber))
            );
    }

    function _returnSigner(bytes32 digest, bytes memory signature)
        internal
        view
        returns (address)
    {
        return ECDSA.recover(digest, signature);
    }
}
