import Web3 from "web3";
import $ from "jquery";
import contract from "truffle-contract";

import gameManagerArtifact from "../../build/contracts/GameManager.json";
import threeInARowArtifact from "../../build/contracts/ThreeInARow.json";

const App = {
  web3: null,
  account: null,
  accountTwo: null,
  activeAccount: null,
  gameManager: null,
  threeInARow: null,
  activeThreeInARowInstance: null,


  start: async function () {
    const {
      web3
    } = this;

    try {

      // // access the gameManager isntance
      this.gameManager = contract(gameManagerArtifact);
      this.gameManager.setProvider(this.web3.currentProvider);

      // access the threeInARow instance
      this.threeInARow = contract(threeInARowArtifact);
      this.threeInARow.setProvider(this.web3.currentProvider);

      // get accounts
      const accounts = await web3.eth.getAccounts();
      this.account = accounts[0];
      this.activeAccount = this.account;
      this.accountTwo = accounts[1];

      // // set the default account for gameManager
      this.gameManager.defaults({
        from: this.account
      });

      // // set the default account for threeInARow
      this.threeInARow.defaults({
        from: this.account
      });

      // refresh top10 high score
      this.refreshHighscore();
      App.gameStopped();
    } catch (error) {
      console.error("Could not connect to contract or chain.");
    }
  },

  setAccountTwo: function () {
    this.threeInARow.defaults({
      from: this.accountTwo
    });
    this.activeAccount = this.accountTwo;
  },

  refreshHighscore: async function () {
    const {
      gameManager
    } = this;
    let gameManagerInstance = await gameManager.deployed();
    let top10 = await gameManagerInstance.getTop10();
    let table = $("#highscore");
    top10[0].forEach(function (value, index) {
      table.append("<tr><td>" + (index + 1) + "</td><td>" + value + "</td><td>" + top10[1][index] + "</td><tr");
    })
  },

  gameStopped: function () {
    $(".game-stopped").show();
    $(".game-over").hide();
    $(".game-running").hide();
  },

  gameRunning: function () {
    $(".game-stopped").hide();
    $(".game-over").hide();
    $(".game-running").show();
  },

  gameJoining: function () {
    $(".game-stopped").hide();
    $(".game-over").show();
    $(".game-running").hide();
  },

  gameOver: function () {
    $(".game-stopped").hide();
    $(".game-over").show();
    $(".game-running").show();
  },

  createNewGame: async function () {
    const {
      gameManager,
      web3,
      threeInARow
    } = this;

    this.gameJoining();

    let gameManagerInstance = await gameManager.deployed();
    let txResult = await gameManagerInstance.startNewGame({
      value: web3.utils.toWei('0.1', 'ether')
    });
    console.log(txResult);
    this.activeThreeInARowInstance = await threeInARow.at(txResult.logs[0].args._gameAddress);

    this.setStatus("Game Address: " + txResult.logs[0].args._gameAddress);

    this.activeThreeInARowInstance.PlayerJoined().on('data', function (event) {
      console.log(event);
      App.gameRunning();
    });

    this.listenToEvents();
  },

  joinGame: async function (gameAddress) {
    const {
      web3,
      threeInARow
    } = this;

    this.activeThreeInARowInstance = await threeInARow.at(gameAddress);
    this.listenToEvents();
    await this.activeThreeInARowInstance.joinGame({
      value: web3.utils.toWei('0.1', 'ether')
    });

  },

  setStone: async function (event) {
    //console.log(event);
    await event.data.instance.setStone(event.data.x, event.data.y);
    for (var i = 0; i < 3; i++) {
      for (var j = 0; j < 3; j++) {
        $($('#board')[0].children[0].children[i].children[j]).off('click');
      }
    }
  },

  updatedBoard: async function (clickable) {
    let board = await this.activeThreeInARowInstance.getBoard();
    console.log(board);
    for (var i = 0; i < board.length; i++) {
      for (var j = 0; j < board[i].length; j++) {
        if (board[i][j] == this.activeAccount) {
          $("#board")[0].children[0].children[i].children[j].innerHTML = "X";
        } else if (board[i][j] != 0) {
          $("#board")[0].children[0].children[i].children[j].innerHTML = "O";
        }
      }
    }

    if (clickable) {
      for (var i = 0; i < board.length; i++) {
        for (var j = 0; j < board[i].length; j++) {
          if ($('#board')[0].children[0].children[i].children[j].innerHTML == "") {
            $($('#board')[0].children[0].children[i].children[j]).off('click').click({
              x: i,
              y: j,
              instance: this.activeThreeInARowInstance
            }, App.setStone);
          }
        }
      };
    }
  },

  listenToEvents: async function () {
    const {
      activeThreeInARowInstance,
      web3
    } = this;

    let self = this;

    activeThreeInARowInstance.NextPlayer().on("data", function (event) {
      console.log(event);
      self.gameRunning();
      if (event.args._player == self.activeAccount) {
        self.setStatus("Your turn");
        self.updatedBoard(true);
      } else {
        self.setStatus("Waiting for opponent");
        self.updatedBoard(false);
        self.gamePlaying();
      }
    });

    activeThreeInARowInstance.GameOverWithWin().on("data", function (event) {
      if (event.args._winner == self.activeAccount) {
        self.setStatus("Congratulations, you are the winner!");
      } else {
        self.setStatus("Oh my! You LOST!");
      }
      self.updatedBoard(false);
      self.refreshHighscore();
      self.gameOver();
    });

    activeThreeInARowInstance.GameOverWithDraw().on("data", function (event) {
      self.setStatus("It is a draw, nobody won!");
      self.updatedBoard(false);
      self.gameOver();
    });
  },

  setStatus: function (message) {
    const status = document.getElementById("status");
    status.innerHTML = message;
  },
};

window.App = App;

window.addEventListener("load", function () {
  if (window.ethereum) {
    // use MetaMask's provider
    App.web3 = new Web3(window.ethereum);
    window.ethereum.enable(); // get permission to access accounts
  } else {
    console.warn(
      "No web3 detected. Falling back to ws://127.0.0.1:8545. You should remove this fallback when you deploy live",
    );
    // fallback - use your fallback strategy (local node / hosted node + in-dapp id mgmt / fail)
    App.web3 = new Web3(
      new Web3.providers.WebsocketProvider("ws://127.0.0.1:8545"),
    );
  }

  App.start();
});