// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {LowLevelETHTransfer} from "./@looksrare/contracts-libs/contracts/lowLevelCallers/LowLevelETHTransfer.sol";
import {Pausable} from "./@openzeppelin/contracts/security/Pausable.sol";

import {AccessControl} from "./@openzeppelin/contracts/access/AccessControl.sol";

import {IMoonOrDoom} from "./interfaces/IMoonOrDoom.sol";
import {PythAdapter} from "./PythAdapter.sol";

/**
 * @title MoonOrDoomOperator
 * @notice This contract is the entrypoint for the operator to interact with the MoonOrDoom and PythAdapter contracts
 * @author YOLO Games protocol team (👀,💎)
 */
contract MoonOrDoomOperator is AccessControl, Pausable, LowLevelETHTransfer {
    bool private initialized;
    IMoonOrDoom public moonOrDoom;
    PythAdapter public pythAdapter;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    uint256 public constant MAX_AHEAD_TIME = 30 seconds;

    /**
     * @notice If the current timestamp + ahead time is not passed the current epoch's lock timestamp,
     *         no performUpkeep is required.
     */
    uint256 public aheadTimeForCheckUpkeep = 3 seconds;

    /**
     * @notice If the current timestamp + ahead time is not passed the current epoch's lock timestamp,
     *         no calls to the core moon or doom contract will be made in performUpkeep.
     */
    uint256 public aheadTimeForPerformUpkeep = 1 seconds;

    event AheadTimeForCheckUpkeepUpdated(uint256 _aheadTimeForCheckUpkeep);
    event AheadTimeForPerformUpkeepUpdated(uint256 _aheadTimeForPerformUpkeep);

    error MoonOrDoomOperator__AheadTimeTooHigh();
    error MoonOrDoomOperator__AlreadyInitialized();
    error MoonOrDoomOperator__NotOperator();
    error MoonOrDoomOperator__NoOp();

    /**
     * @param defaultAdmin The default admin of the contract
     * @param operator The operator of the contract
     */
    constructor(address defaultAdmin, address operator) {
        _setupRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _setupRole(OPERATOR_ROLE, operator);
    }

    /**
     * @notice Initializes the contract, only callable by the operator
     * @param _moonOrDoom Moon or Doom address
     * @param _pythAdapter Pyth adapter address
     */
    function initialize(address _moonOrDoom, address _pythAdapter) external onlyRole(OPERATOR_ROLE) {
        if (initialized) {
            revert MoonOrDoomOperator__AlreadyInitialized();
        }

        moonOrDoom = IMoonOrDoom(_moonOrDoom);
        pythAdapter = PythAdapter(_pythAdapter);

        initialized = true;
    }

    /**
     * @notice Checks if the operator should call performUpkeep
     * @return upkeepNeeded Whether the operator should call performUpkeep *now*
     * @return priceDataNeeded Whether the operator should call performUpkeep with price data
     */
    function checkUpkeep() external view returns (bool upkeepNeeded, bool priceDataNeeded) {
        if (!paused()) {
            if (moonOrDoom.paused()) {
                // need to unpause
                upkeepNeeded = true;
            } else {
                if (!moonOrDoom.genesisStartOnce()) {
                    upkeepNeeded = true;
                    // priceDataNeeded = false;
                } else if (!moonOrDoom.genesisLockOnce()) {
                    uint256 lockTimestamp = _getRoundLockTimestamp(moonOrDoom.currentEpoch());

                    // Too early for locking of round, skip current job (also means previous lockRound was successful)
                    if (_tooEarlyToDoAnything(lockTimestamp, aheadTimeForCheckUpkeep)) {
                        // upkeepNeeded = false;
                        // priceDataNeeded = false;
                    } else if (_passRoundLockTimestampWithBuffer(lockTimestamp)) {
                        // Too late to lock round, need to pause
                        upkeepNeeded = true;
                        // priceDataNeeded = false;
                    } else {
                        // run genesisLockRound
                        upkeepNeeded = true;
                        priceDataNeeded = true;
                    }
                } else {
                    uint256 lockTimestamp = _getRoundLockTimestamp(moonOrDoom.currentEpoch());

                    if (block.timestamp + aheadTimeForCheckUpkeep > lockTimestamp) {
                        // Too early for end/lock/start of round, skip current job
                        if (_tooEarlyToDoAnything(lockTimestamp, aheadTimeForCheckUpkeep)) {
                            // upkeepNeeded = false;
                            // priceDataNeeded = false;
                        } else if (_passRoundLockTimestampWithBuffer(lockTimestamp)) {
                            // Too late to end round, need to pause
                            upkeepNeeded = true;
                            // priceDataNeeded = false;
                        } else {
                            // run executeRound
                            upkeepNeeded = true;
                            priceDataNeeded = true;
                        }
                    }
                }
            }
        }
    }

    /**
     * @notice Performs the upkeep, only callable by the operator
     * @param priceUpdateData The price update data to be passed to PythAdapter
     */
    function performUpkeep(bytes[] calldata priceUpdateData) external payable whenNotPaused onlyRole(OPERATOR_ROLE) {
        if (moonOrDoom.paused()) {
            moonOrDoom.unpause();
        } else {
            if (!moonOrDoom.genesisStartOnce()) {
                moonOrDoom.genesisStartRound();
            } else if (!moonOrDoom.genesisLockOnce()) {
                uint256 lockTimestamp = _getRoundLockTimestamp(moonOrDoom.currentEpoch());

                if (_tooEarlyToDoAnything(lockTimestamp, aheadTimeForPerformUpkeep)) {
                    revert MoonOrDoomOperator__NoOp();
                } else if (_passRoundLockTimestampWithBuffer(lockTimestamp)) {
                    moonOrDoom.pause();
                } else {
                    pythAdapter.updateFeeds{value: msg.value}(priceUpdateData);
                    moonOrDoom.genesisLockRound();
                    _refundETHIfAny();
                }
            } else {
                uint256 lockTimestamp = _getRoundLockTimestamp(moonOrDoom.currentEpoch());

                if (block.timestamp + aheadTimeForCheckUpkeep > lockTimestamp) {
                    // Too early for end/lock/start of round, skip current job
                    if (_tooEarlyToDoAnything(lockTimestamp, aheadTimeForPerformUpkeep)) {
                        revert MoonOrDoomOperator__NoOp();
                    } else if (_passRoundLockTimestampWithBuffer(lockTimestamp)) {
                        moonOrDoom.pause();
                    } else {
                        pythAdapter.updateFeeds{value: msg.value}(priceUpdateData);
                        moonOrDoom.executeRound();
                        _refundETHIfAny();
                    }
                } else {
                    revert MoonOrDoomOperator__NoOp();
                }
            }
        }
    }

    /**
     * @notice Sets aheadTimeForCheckUpkeep, only callable by the default admin
     * @param _aheadTimeForCheckUpkeep The new aheadTimeForCheckUpkeep
     */
    function setAheadTimeForCheckUpkeep(uint256 _aheadTimeForCheckUpkeep) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_aheadTimeForCheckUpkeep > MAX_AHEAD_TIME) {
            revert MoonOrDoomOperator__AheadTimeTooHigh();
        }

        aheadTimeForCheckUpkeep = _aheadTimeForCheckUpkeep;
        emit AheadTimeForCheckUpkeepUpdated(_aheadTimeForCheckUpkeep);
    }

    /**
     * @notice Sets aheadTimeForPerformUpkeep, only callable by the default admin
     * @param _aheadTimeForPerformUpkeep The new aheadTimeForPerformUpkeep
     */
    function setAheadTimeForPerformUpkeep(uint256 _aheadTimeForPerformUpkeep) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_aheadTimeForPerformUpkeep > MAX_AHEAD_TIME) {
            revert MoonOrDoomOperator__AheadTimeTooHigh();
        }

        aheadTimeForPerformUpkeep = _aheadTimeForPerformUpkeep;
        emit AheadTimeForPerformUpkeepUpdated(_aheadTimeForPerformUpkeep);
    }

    /**
     * @notice Pause the contract, only callable by the default admin
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause the contract, only callable by the default admin
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @param epoch The epoch to get the lock timestamp for
     * @return The lock timestamp for the epoch
     */
    function _getRoundLockTimestamp(uint256 epoch) private view returns (uint256) {
        IMoonOrDoom.Round memory round = moonOrDoom.rounds(epoch);
        return round.lockTimestamp;
    }

    /**
     * @param lockTimestamp The lock timestamp for the epoch
     * @param aheadTime The ahead time
     * @return Whether it's too early to make any calls to the moon or doom contract
     */
    function _tooEarlyToDoAnything(uint256 lockTimestamp, uint256 aheadTime) private view returns (bool) {
        return lockTimestamp == 0 || block.timestamp + aheadTime < lockTimestamp;
    }

    /**
     * @param lockTimestamp The lock timestamp for the epoch
     * @return Whether the current timestamp is passed the epoch's lock timestamp plus buffer
     */
    function _passRoundLockTimestampWithBuffer(uint256 lockTimestamp) private view returns (bool) {
        return lockTimestamp != 0 && block.timestamp > (lockTimestamp + moonOrDoom.bufferSeconds());
    }

    function _refundETHIfAny() private {
        uint256 balance = address(this).balance;
        if (balance != 0) {
            _transferETH(msg.sender, balance);
        }
    }

    receive() external payable {}
}
