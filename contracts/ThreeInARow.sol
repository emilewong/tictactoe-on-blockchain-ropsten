pragma solidity ^0.5.0;

import {GameManager} from "./GameManager.sol";

contract ThreeInARow {

    GameManager gameManager;

    uint256 public gameCost = 0.1 ether;

    address payable public player1;
    address payable public player2;

    address payable activePlayer;

    event PlayerJoined(address _player);
    event NextPlayer(address _player);

    event GameOverWithWin(address _winner);
    event GameOverWithDraw();
    event PayoutSuccess(address _receiver, uint _amountInWei);

    uint8 moveCounter;

    uint balanceToWithdrawPlayer1;
    uint balanceToWithdrawPlayer2;

    bool gameActive;

    address[3][3] gameBoard;

    uint gameValidUntil;
    uint timeToReact = 3 minutes;

    constructor(address _addrGameManager, address payable _player1) public payable {
        gameManager = GameManager(_addrGameManager);
        require(msg.value == gameCost, "Submit more money! Aborting!");
        player1 = _player1;
        //more functionality here - later!
    }

    function joinGame() public payable {
        //here player2 joins the game
        assert(player2 == address(0x0));
        assert(gameActive == false);
        require(msg.value == gameCost, "Submit more money! Aborting!");

        player2 = msg.sender;
        emit PlayerJoined(player2);

        if(block.number % 2 == 0 ){
            activePlayer = player2;
        }else {
            activePlayer = player1;

        }

        gameActive = true;

        gameValidUntil = now + timeToReact;

        emit NextPlayer(activePlayer);

    }

    function getBoard() public view returns(address[3][3] memory) {
        //here we return the board
        return gameBoard;
    }

    function setStone(uint8 x, uint8 y) public {
        uint8 boardSize = uint8(gameBoard.length);
        require(gameBoard[x][y] == address(0x0));
        assert(gameActive);
        require(x < boardSize);
        require(y < boardSize);
        require(msg.sender == activePlayer);
        require(gameValidUntil >= now);
        moveCounter++;
        //we set the stone here
        gameBoard[x][y] = msg.sender;

        // check if it's a win
        /**
         *     |   |
         *  ---|---|---
         *     |   |
         *  ---|---|---
         *     |   |
         *
         *  */

         // check horizontal stone for winning
         for(uint8 i = 0; i < boardSize; i++) {
             if(gameBoard[i][y] != activePlayer) {
                 break;
             }

             if (i == boardSize - 1) {
                 setWinner(activePlayer);
                 return;
             }
         }

         // check vertical stone for winning
         for(uint8 i = 0; i < boardSize; i++) {
             if(gameBoard[x][i] != activePlayer) {
                 break;
             }

             if (i == boardSize - 1) {
                 setWinner(activePlayer);
                 return;
             }
         }

         // check diagonal stone for winning

         if(x == y) {
             for(uint i = 0; i < boardSize; i ++) {
                if(gameBoard[i][i] != activePlayer) {
                 break;
                }

                 if (i == boardSize -1) {
                     setWinner(activePlayer);
                     return;
                 }
            }
         }

        // check anti-diagonal stone for winning
        if((x + y) == boardSize -1) {
            for(uint i = 0; i < boardSize; i ++) {
             if(gameBoard[i][(boardSize-1) -i] != activePlayer) {
                 break;
             }

             if (i == boardSize -1) {
                 setWinner(activePlayer);
                 return;
             }
         }
        }


        // check if it's a setDraw
        if(moveCounter == boardSize**2) {
            setDraw();
        }

        if(activePlayer == player1) {
            activePlayer = player2;
        } else {
            activePlayer =  player1;
        }

        emit NextPlayer(activePlayer);
    }

    function setWinner(address payable _player) private {
        gameActive = false;
        gameManager.enterWinner(_player);
        uint balanceToPayout = address(this).balance;
        if(_player.send(balanceToPayout) != true) {
            if(_player == player1) {
                balanceToWithdrawPlayer1 += balanceToPayout;
            } else {
                balanceToWithdrawPlayer2 += balanceToPayout;
            }
        } else {
            emit PayoutSuccess(_player, balanceToPayout);
        }
        emit GameOverWithWin(_player);
    }

    function setDraw() private {
        uint balanceToPayout = address(this).balance / 2;

        if (player1.send(balanceToPayout) == false) {
            balanceToWithdrawPlayer1 += balanceToPayout;
        } else {
            emit PayoutSuccess(player1, balanceToPayout);
        }

        if (player2.send(balanceToPayout) == false) {
            balanceToWithdrawPlayer2 += balanceToPayout;
        } else {
            emit PayoutSuccess(player2, balanceToPayout);
        }
        emit GameOverWithDraw();
    }

    function withdrawWin(address payable _to) public {
        if(msg.sender == player1) {
            require(balanceToWithdrawPlayer1 > 0);
            uint balanceToWithdraw = balanceToWithdrawPlayer1;
            balanceToWithdrawPlayer1 = 0;
            _to.transfer(balanceToWithdraw);
            emit PayoutSuccess(_to, balanceToWithdraw);
        }

        if(msg.sender == player2) {
            require(balanceToWithdrawPlayer2 > 0);
            uint balanceToWithdraw = balanceToWithdrawPlayer2;
            balanceToWithdrawPlayer2 = 0;
            _to.transfer(balanceToWithdraw);
            emit PayoutSuccess(_to, balanceToWithdraw);
        }
    }

    function emergencyCashout() public {
        require(gameValidUntil < now);
        require(gameActive);
        setDraw();
    }
}