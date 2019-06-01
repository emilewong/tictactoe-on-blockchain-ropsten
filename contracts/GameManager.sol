pragma solidity ^0.5.0;

import {ThreeInARow} from "./ThreeInARow.sol";
import {HighscoreManager} from "./HighscoreManager.sol";

contract GameManager {

    HighscoreManager public highscoremanager;

    event EventGameCreated(address _player, address _gameAddress);

    mapping(address => bool) allowedToEnterHighScore;

    constructor() public {
        highscoremanager = new HighscoreManager(address(this));
    }

    modifier onlyInGameHighscoreEditing() {
        require(allowedToEnterHighScore[msg.sender], "You are not allowed to Enter a Highscore!");
        _;
    }

    function enterWinner(address _winner) public onlyInGameHighscoreEditing {
        highscoremanager.addWin(_winner);
    }

    function getTop10() public view returns (address[10] memory, uint[10] memory) {
        return highscoremanager.getTop10();
    }

    function startNewGame() public payable {
        ThreeInARow threeInARow = (new ThreeInARow).value(msg.value)(address(this), msg.sender);
        allowedToEnterHighScore[address(threeInARow)] = true;
        emit EventGameCreated(msg.sender, address(threeInARow));
    }
}
