// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {LowLevelETHTransfer} from "./@looksrare/contracts-libs/contracts/lowLevelCallers/LowLevelETHTransfer.sol";

import {IPyth} from "./@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import {PythStructs} from "./@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import {AggregatorV3Interface} from "./interfaces/AggregatorV3Interface.sol";
import {AccessControl} from "./@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title PythAdapter
 * @notice This contract provides a Chainlink AggregatorV3Interface interface for Pyth price feeds
 * @author YOLO Games protocol team (👀,💎)
 */
contract PythAdapter is AggregatorV3Interface, LowLevelETHTransfer, AccessControl {
    IPyth public immutable PYTH;
    bytes32 public immutable PRICE_ID;
    uint8 private immutable DECIMALS;
    string private DESCRIPTION;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    struct RoundData {
        uint80 roundId;
        int256 answer;
        uint256 startedAt;
        uint256 updatedAt;
        uint80 answeredInRound;
    }

    uint80 public currentRoundId;

    mapping(uint256 => RoundData) public rounds;

    /**
     * @param _pyth Pyth price feed address
     * @param _priceId Pyth price feed ID
     * @param _description Pyth price feed description
     * @param _defaultAdmin The default admin of the contract
     */
    constructor(
        address _pyth,
        bytes32 _priceId,
        string memory _description,
        address _defaultAdmin
    ) {
        PYTH = IPyth(_pyth);
        PRICE_ID = _priceId;

        PythStructs.Price memory price = PYTH.getPriceUnsafe(PRICE_ID);
        DECIMALS = uint8(uint32(-price.expo));

        DESCRIPTION = _description;

        _setupRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);
    }

    /**
     * @notice Updates the price feed data from Pyth
     * @param priceUpdateData Price update data from Pyth
     */
    function updateFeeds(bytes[] calldata priceUpdateData) external payable onlyRole(OPERATOR_ROLE) {
        // Update the prices to the latest available values and pay the required fee for it. The `priceUpdateData` data
        // should be retrieved from our off-chain Price Service API using the `pyth-evm-js` package.
        // See section "How Pyth Works on EVM Chains" below for more information.
        uint256 fee = PYTH.getUpdateFee(priceUpdateData);
        PYTH.updatePriceFeeds{value: fee}(priceUpdateData);

        // getValidTimePeriod returns 60, that means if the price must be published within 60 seconds
        PythStructs.Price memory price = PYTH.getPrice(PRICE_ID);
        uint256 publishedTime = price.publishTime;
        uint80 roundId = ++currentRoundId;
        rounds[currentRoundId] = RoundData({
            roundId: roundId,
            answer: price.price,
            startedAt: publishedTime,
            updatedAt: publishedTime,
            answeredInRound: roundId
        });

        uint256 balance = address(this).balance;
        if (balance != 0) {
            _transferETH(msg.sender, balance);
        }
    }

    // Use https://arbiscan.io/address/0x639fe6ab55c921f74e7fac1ee960c0b6293ba612#readContract as reference
    function decimals() external view returns (uint8) {
        return DECIMALS;
    }

    function description() external view returns (string memory) {
        return DESCRIPTION;
    }

    function version() external pure returns (uint256) {
        return 1;
    }

    /**
     * @return roundId The round ID.
     * @return answer The price.
     * @return startedAt Timestamp of when the round started.
     * @return updatedAt Timestamp of when the round was updated.
     * @return answeredInRound The round ID of the round in which the answer was computed.
     */
    function getRoundData(uint80 _roundId)
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        roundId = _roundId;
        answer = rounds[_roundId].answer;
        startedAt = rounds[_roundId].startedAt;
        updatedAt = rounds[_roundId].updatedAt;
        answeredInRound = rounds[_roundId].answeredInRound;
    }

    /**
     * @return roundId The round ID.
     * @return answer The price.
     * @return startedAt Timestamp of when the round started.
     * @return updatedAt Timestamp of when the round was updated.
     * @return answeredInRound The round ID of the round in which the answer was computed.
     */
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        roundId = currentRoundId;
        answer = rounds[roundId].answer;
        startedAt = rounds[roundId].startedAt;
        updatedAt = rounds[roundId].updatedAt;
        answeredInRound = rounds[roundId].answeredInRound;
    }
}
