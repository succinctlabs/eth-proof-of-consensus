// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import {RLPReader} from "hamdiallam/Solidity-RLP@2.0.5/contracts/RLPReader.sol";
import {StateProofVerifier as Verifier} from "./StateProofVerifier.sol";
import {SafeMath} from "./SafeMath.sol";


interface IPriceHelper {
    function get_dy(
        int128 i,
        int128 j,
        uint256 dx,
        uint256[2] memory xp,
        uint256 A,
        uint256 fee
    ) external pure returns (uint256);
}


interface IStableSwap {
    function fee() external view returns (uint256);
    function A_precise() external view returns (uint256);
}


/**
 * @title
 *   A trustless oracle for the stETH/ETH Curve pool using Merkle Patricia
 *   proofs of Ethereum state.
 *
 * @notice
 *   The oracle currently assumes that the pool's fee and A (amplification
 *   coefficient) values don't change between the time of proof generation
 *   and submission.
 */
contract StableSwapStateOracle {
    using RLPReader for bytes;
    using RLPReader for RLPReader.RLPItem;
    using SafeMath for uint256;

    /**
     * @notice Logs the updated slot values of Curve pool and stETH contracts.
     */
    event SlotValuesUpdated(
        uint256 timestamp,
        uint256 poolEthBalance,
        uint256 poolAdminEthBalance,
        uint256 poolAdminStethBalance,
        uint256 stethPoolShares,
        uint256 stethTotalShares,
        uint256 stethBeaconBalance,
        uint256 stethBufferedEther,
        uint256 stethDepositedValidators,
        uint256 stethBeaconValidators
    );

    /**
     * @notice Logs the updated stETH and ETH pool balances and the calculated stETH/ETH price.
     */
    event PriceUpdated(
        uint256 timestamp,
        uint256 etherBalance,
        uint256 stethBalance,
        uint256 stethPrice
    );

    /**
     * @notice Logs the updated price update threshold percentage advised to offchain clients.
     */
    event PriceUpdateThresholdChanged(uint256 threshold);

    /**
     * @notice
     *   Logs the updated address having the right to change the advised price update threshold.
     */
    event AdminChanged(address admin);


    /// @dev Reporting data that is more fresh than this number of blocks ago is prohibited
    uint256 constant public MIN_BLOCK_DELAY = 15;

    // Constants for offchain proof generation

    address constant public POOL_ADDRESS = 0xDC24316b9AE028F1497c275EB9192a3Ea0f67022;
    address constant public STETH_ADDRESS = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;

    /// @dev keccak256(abi.encodePacked(uint256(1)))
    bytes32 constant public POOL_ADMIN_BALANCES_0_POS = 0xb10e2d527612073b26eecdfd717e6a320cf44b4afac2b0732d9fcbe2b7fa0cf6;

    /// @dev bytes32(uint256(POOL_ADMIN_BALANCES_0_POS) + 1)
    bytes32 constant public POOL_ADMIN_BALANCES_1_POS = 0xb10e2d527612073b26eecdfd717e6a320cf44b4afac2b0732d9fcbe2b7fa0cf7;

    /// @dev keccak256(abi.encodePacked(uint256(0xDC24316b9AE028F1497c275EB9192a3Ea0f67022), uint256(0)))
    bytes32 constant public STETH_POOL_SHARES_POS = 0xae68078d7ee25b2b7bcb7d4b9fe9acf61f251fe08ff637df07889375d8385158;

    /// @dev keccak256("lido.StETH.totalShares")
    bytes32 constant public STETH_TOTAL_SHARES_POS = 0xe3b4b636e601189b5f4c6742edf2538ac12bb61ed03e6da26949d69838fa447e;

    /// @dev keccak256("lido.Lido.beaconBalance")
    bytes32 constant public STETH_BEACON_BALANCE_POS = 0xa66d35f054e68143c18f32c990ed5cb972bb68a68f500cd2dd3a16bbf3686483;

    /// @dev keccak256("lido.Lido.bufferedEther")
    bytes32 constant public STETH_BUFFERED_ETHER_POS = 0xed310af23f61f96daefbcd140b306c0bdbf8c178398299741687b90e794772b0;

    /// @dev keccak256("lido.Lido.depositedValidators")
    bytes32 constant public STETH_DEPOSITED_VALIDATORS_POS = 0xe6e35175eb53fc006520a2a9c3e9711a7c00de6ff2c32dd31df8c5a24cac1b5c;

    /// @dev keccak256("lido.Lido.beaconValidators")
    bytes32 constant public STETH_BEACON_VALIDATORS_POS = 0x9f70001d82b6ef54e9d3725b46581c3eb9ee3aa02b941b6aa54d678a9ca35b10;

    // Constants for onchain proof verification

    /// @dev keccak256(abi.encodePacked(POOL_ADDRESS))
    bytes32 constant POOL_ADDRESS_HASH = 0xc70f76036d72b7bb865881e931082ea61bb4f13ec9faeb17f0591b18b6fafbd7;

    /// @dev keccak256(abi.encodePacked(STETH_ADDRESS))
    bytes32 constant STETH_ADDRESS_HASH = 0x6c958a912fe86c83262fbd4973f6bd042cef76551aaf679968f98665979c35e7;

    /// @dev keccak256(abi.encodePacked(POOL_ADMIN_BALANCES_0_POS))
    bytes32 constant POOL_ADMIN_BALANCES_0_HASH = 0xb5d9d894133a730aa651ef62d26b0ffa846233c74177a591a4a896adfda97d22;

    /// @dev keccak256(abi.encodePacked(POOL_ADMIN_BALANCES_1_POS)
    bytes32 constant POOL_ADMIN_BALANCES_1_HASH = 0xea7809e925a8989e20c901c4c1da82f0ba29b26797760d445a0ce4cf3c6fbd31;

    /// @dev keccak256(abi.encodePacked(STETH_POOL_SHARES_POS)
    bytes32 constant STETH_POOL_SHARES_HASH = 0xe841c8fb2710e169d6b63e1130fb8013d57558ced93619655add7aef8c60d4dc;

    /// @dev keccak256(abi.encodePacked(STETH_TOTAL_SHARES_POS)
    bytes32 constant STETH_TOTAL_SHARES_HASH = 0x4068b5716d4c00685289292c9cdc7e059e67159cd101476377efe51ba7ab8e9f;

    /// @dev keccak256(abi.encodePacked(STETH_BEACON_BALANCE_POS)
    bytes32 constant STETH_BEACON_BALANCE_HASH = 0xa6965d4729b36ed8b238f6ba55294196843f8be2850c5f63b6fb6d29181b50f8;

    /// @dev keccak256(abi.encodePacked(STETH_BUFFERED_ETHER_POS)
    bytes32 constant STETH_BUFFERED_ETHER_HASH = 0xa39079072910ef75f32ddc4f40104882abfc19580cc249c694e12b6de868ee1d;

    /// @dev keccak256(abi.encodePacked(STETH_DEPOSITED_VALIDATORS_POS)
    bytes32 constant STETH_DEPOSITED_VALIDATORS_HASH = 0x17216d3ffd8719eeee6d8052f7c1e6269bd92d2390d3e3fc4cde1f026e427fb3;

    /// @dev keccak256(abi.encodePacked(STETH_BEACON_VALIDATORS_POS)
    bytes32 constant STETH_BEACON_VALIDATORS_HASH = 0x6fd60d3960d8a32cbc1a708d6bf41bbce8152e61e72b2236d5e1ecede9c4cc72;

    uint256 constant internal STETH_DEPOSIT_SIZE = 32 ether;

    /**
     * @dev A helper contract for calculating stETH/ETH price from its stETH and ETH balances.
     */
    IPriceHelper internal helper;

    /**
     * @notice The admin has the right to set the suggested price update threshold (see below).
     */
    address public admin;

    /**
     * @notice
     *   The price update threshold percentage advised to oracle clients.
     *   Expressed in basis points: 10000 BP equal to 100%, 100 BP to 1%.
     *
     * @dev
     *   If the current price in the pool differs less than this, the clients are advised to
     *   skip updating the oracle. However, this threshold is not enforced, so clients are
     *   free to update the oracle with any valid price.
     */
    uint256 public priceUpdateThreshold;

    /**
     * @notice The timestamp of the proven pool state/price.
     */
    uint256 public timestamp;

    /**
     * @notice The proven ETH balance of the pool.
     */
    uint256 public etherBalance;

    /**
     * @notice The proven stETH balance of the pool.
     */
    uint256 public stethBalance;

    /**
     * @notice The proven stETH/ETH price in the pool.
     */
    uint256 public stethPrice;


    /**
     * @param _helper Address of the deployed instance of the StableSwapPriceHelper.vy contract.
     * @param _admin The address that has the right to set the suggested price update threshold.
     * @param _priceUpdateThreshold The initial value of the suggested price update threshold.
     *        Expressed in basis points, 10000 BP corresponding to 100%.
     */
    constructor(IPriceHelper _helper, address _admin, uint256 _priceUpdateThreshold) public {
        helper = _helper;
        _setAdmin(_admin);
        _setPriceUpdateThreshold(_priceUpdateThreshold);
    }


    /**
     * @notice Passes the right to set the suggested price update threshold to a new address.
     */
    function setAdmin(address _admin) external {
        require(msg.sender == admin);
        _setAdmin(_admin);
    }


    /**
     * @notice Sets the suggested price update threshold.
     *
     * @param _priceUpdateThreshold The suggested price update threshold.
     *        Expressed in basis points, 10000 BP corresponding to 100%.
     */
    function setPriceUpdateThreshold(uint256 _priceUpdateThreshold) external {
        require(msg.sender == admin);
        _setPriceUpdateThreshold(_priceUpdateThreshold);
    }


    /**
     * @notice Returns a set of values used by the clients for proof generation.
     */
    function getProofParams() external view returns (
        address poolAddress,
        address stethAddress,
        bytes32 poolAdminEtherBalancePos,
        bytes32 poolAdminCoinBalancePos,
        bytes32 stethPoolSharesPos,
        bytes32 stethTotalSharesPos,
        bytes32 stethBeaconBalancePos,
        bytes32 stethBufferedEtherPos,
        bytes32 stethDepositedValidatorsPos,
        bytes32 stethBeaconValidatorsPos,
        uint256 advisedPriceUpdateThreshold
    ) {
        return (
            POOL_ADDRESS,
            STETH_ADDRESS,
            POOL_ADMIN_BALANCES_0_POS,
            POOL_ADMIN_BALANCES_1_POS,
            STETH_POOL_SHARES_POS,
            STETH_TOTAL_SHARES_POS,
            STETH_BEACON_BALANCE_POS,
            STETH_BUFFERED_ETHER_POS,
            STETH_DEPOSITED_VALIDATORS_POS,
            STETH_BEACON_VALIDATORS_POS,
            priceUpdateThreshold
        );
    }


    /**
     * @return _timestamp The timestamp of the proven pool state/price.
     *         Will be zero in the case no state has been reported yet.
     * @return _etherBalance The proven ETH balance of the pool.
     * @return _stethBalance The proven stETH balance of the pool.
     * @return _stethPrice The proven stETH/ETH price in the pool.
     */
    function getState() external view returns (
        uint256 _timestamp,
        uint256 _etherBalance,
        uint256 _stethBalance,
        uint256 _stethPrice
    ) {
        return (timestamp, etherBalance, stethBalance, stethPrice);
    }


    /**
     * @notice Used by the offchain clients to submit the proof.
     *
     * @dev Reverts unless:
     *   - the block the submitted data corresponds to is in the chain;
     *   - the block is at least `MIN_BLOCK_DELAY` blocks old;
     *   - all submitted proofs are valid.
     *
     * @param _blockHeaderRlpBytes RLP-encoded block header.
     *
     * @param _proofRlpBytes RLP-encoded list of Merkle Patricia proofs:
     *    1. proof of the Curve pool contract account;
     *    2. proof of the stETH contract account;
     *    3. proof of the `admin_balances[0]` slot of the Curve pool contract;
     *    4. proof of the `admin_balances[1]` slot of the Curve pool contract;
     *    5. proof of the `shares[0xDC24316b9AE028F1497c275EB9192a3Ea0f67022]` slot of stETH contract;
     *    6. proof of the `keccak256("lido.StETH.totalShares")` slot of stETH contract;
     *    7. proof of the `keccak256("lido.Lido.beaconBalance")` slot of stETH contract;
     *    8. proof of the `keccak256("lido.Lido.bufferedEther")` slot of stETH contract;
     *    9. proof of the `keccak256("lido.Lido.depositedValidators")` slot of stETH contract;
     *   10. proof of the `keccak256("lido.Lido.beaconValidators")` slot of stETH contract.
     */
    function submitState(bytes memory _blockHeaderRlpBytes, bytes memory _proofRlpBytes)
        external
    {
        Verifier.BlockHeader memory blockHeader = Verifier.verifyBlockHeader(_blockHeaderRlpBytes);

        {
            uint256 currentBlock = block.number;
            // ensure block finality
            require(
                currentBlock > blockHeader.number &&
                currentBlock - blockHeader.number >= MIN_BLOCK_DELAY,
                "block too fresh"
            );
        }

        require(blockHeader.timestamp > timestamp, "stale data");

        RLPReader.RLPItem[] memory proofs = _proofRlpBytes.toRlpItem().toList();
        require(proofs.length == 10, "total proofs");

        Verifier.Account memory accountPool = Verifier.extractAccountFromProof(
            POOL_ADDRESS_HASH,
            blockHeader.stateRootHash,
            proofs[0].toList()
        );

        require(accountPool.exists, "accountPool");

        Verifier.Account memory accountSteth = Verifier.extractAccountFromProof(
            STETH_ADDRESS_HASH,
            blockHeader.stateRootHash,
            proofs[1].toList()
        );

        require(accountSteth.exists, "accountSteth");

        Verifier.SlotValue memory slotPoolAdminBalances0 = Verifier.extractSlotValueFromProof(
            POOL_ADMIN_BALANCES_0_HASH,
            accountPool.storageRoot,
            proofs[2].toList()
        );

        require(slotPoolAdminBalances0.exists, "adminBalances0");

        Verifier.SlotValue memory slotPoolAdminBalances1 = Verifier.extractSlotValueFromProof(
            POOL_ADMIN_BALANCES_1_HASH,
            accountPool.storageRoot,
            proofs[3].toList()
        );

        require(slotPoolAdminBalances1.exists, "adminBalances1");

        Verifier.SlotValue memory slotStethPoolShares = Verifier.extractSlotValueFromProof(
            STETH_POOL_SHARES_HASH,
            accountSteth.storageRoot,
            proofs[4].toList()
        );

        require(slotStethPoolShares.exists, "poolShares");

        Verifier.SlotValue memory slotStethTotalShares = Verifier.extractSlotValueFromProof(
            STETH_TOTAL_SHARES_HASH,
            accountSteth.storageRoot,
            proofs[5].toList()
        );

        require(slotStethTotalShares.exists, "totalShares");

        Verifier.SlotValue memory slotStethBeaconBalance = Verifier.extractSlotValueFromProof(
            STETH_BEACON_BALANCE_HASH,
            accountSteth.storageRoot,
            proofs[6].toList()
        );

        require(slotStethBeaconBalance.exists, "beaconBalance");

        Verifier.SlotValue memory slotStethBufferedEther = Verifier.extractSlotValueFromProof(
            STETH_BUFFERED_ETHER_HASH,
            accountSteth.storageRoot,
            proofs[7].toList()
        );

        require(slotStethBufferedEther.exists, "bufferedEther");

        Verifier.SlotValue memory slotStethDepositedValidators = Verifier.extractSlotValueFromProof(
            STETH_DEPOSITED_VALIDATORS_HASH,
            accountSteth.storageRoot,
            proofs[8].toList()
        );

        require(slotStethDepositedValidators.exists, "depositedValidators");

        Verifier.SlotValue memory slotStethBeaconValidators = Verifier.extractSlotValueFromProof(
            STETH_BEACON_VALIDATORS_HASH,
            accountSteth.storageRoot,
            proofs[9].toList()
        );

        require(slotStethBeaconValidators.exists, "beaconValidators");

        emit SlotValuesUpdated(
            blockHeader.timestamp,
            accountPool.balance,
            slotPoolAdminBalances0.value,
            slotPoolAdminBalances1.value,
            slotStethPoolShares.value,
            slotStethTotalShares.value,
            slotStethBeaconBalance.value,
            slotStethBufferedEther.value,
            slotStethDepositedValidators.value,
            slotStethBeaconValidators.value
        );

        uint256 newEtherBalance = accountPool.balance.sub(slotPoolAdminBalances0.value);
        uint256 newStethBalance = _getStethBalanceByShares(
            slotStethPoolShares.value,
            slotStethTotalShares.value,
            slotStethBeaconBalance.value,
            slotStethBufferedEther.value,
            slotStethDepositedValidators.value,
            slotStethBeaconValidators.value
        ).sub(slotPoolAdminBalances1.value);

        uint256 newStethPrice = _calcPrice(newEtherBalance, newStethBalance);

        timestamp = blockHeader.timestamp;
        etherBalance = newEtherBalance;
        stethBalance = newStethBalance;
        stethPrice = newStethPrice;

        emit PriceUpdated(blockHeader.timestamp, newEtherBalance, newStethBalance, newStethPrice);
    }


    /**
     * @dev Given the values of stETH smart contract slots, calculates the amount of stETH owned
     *      by the Curve pool by reproducing calculations performed in the stETH contract.
     */
    function _getStethBalanceByShares(
        uint256 _shares,
        uint256 _totalShares,
        uint256 _beaconBalance,
        uint256 _bufferedEther,
        uint256 _depositedValidators,
        uint256 _beaconValidators
    )
        internal pure returns (uint256)
    {
        // https://github.com/lidofinance/lido-dao/blob/v1.0.0/contracts/0.4.24/StETH.sol#L283
        // https://github.com/lidofinance/lido-dao/blob/v1.0.0/contracts/0.4.24/Lido.sol#L719
        // https://github.com/lidofinance/lido-dao/blob/v1.0.0/contracts/0.4.24/Lido.sol#L706
        if (_totalShares == 0) {
            return 0;
        }
        uint256 transientBalance = _depositedValidators.sub(_beaconValidators).mul(STETH_DEPOSIT_SIZE);
        uint256 totalPooledEther = _bufferedEther.add(_beaconBalance).add(transientBalance);
        return _shares.mul(totalPooledEther).div(_totalShares);
    }


    /**
     * @dev Given the ETH and stETH balances of the Curve pool, calculates the corresponding
     *      stETH/ETH price by reproducing calculations performed in the pool contract.
     */
    function _calcPrice(uint256 _etherBalance, uint256 _stethBalance) internal view returns (uint256) {
        uint256 A = IStableSwap(POOL_ADDRESS).A_precise();
        uint256 fee = IStableSwap(POOL_ADDRESS).fee();
        return helper.get_dy(1, 0, 10**18, [_etherBalance, _stethBalance], A, fee);
    }


    function _setPriceUpdateThreshold(uint256 _priceUpdateThreshold) internal {
        require(_priceUpdateThreshold <= 10000);
        priceUpdateThreshold = _priceUpdateThreshold;
        emit PriceUpdateThresholdChanged(_priceUpdateThreshold);
    }


    function _setAdmin(address _admin) internal {
        require(_admin != address(0));
        require(_admin != admin);
        admin = _admin;
        emit AdminChanged(_admin);
    }
}
