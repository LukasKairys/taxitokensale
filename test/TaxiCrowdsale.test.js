const BigNumber = web3.BigNumber;

const should = require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bignumber')(BigNumber))
  .should();

const TaxiToken = artifacts.require("./TaxiToken")
const TaxiCrowdsale = artifacts.require("./TaxiCrowdsale");

contract('TaxiCrowdsaleTest', function (accounts) {

  let investor = accounts[0];
  let wallet = accounts[1];
  let purchaser = accounts[2];

  beforeEach(async function () {
    this.token = await TaxiToken.new();
    this.crowdsale = await TaxiCrowdsale.new(wallet, this.token.address);
    await this.token.transferOwnership(this.crowdsale.address);
  });

  describe('accepting payments', function () {
    it('should not accept payments while not started', async function () {
      this.crowdsale.should.exist;

      try {
          await this.crowdsale.send(ether(10));
          assert.fail('Expected reject not received');
      } catch (error) {
        assert(error.message.search('invalid opcode') > 0, 'Wrong error message received: ' + error.message);
      }
    });

    it('should accept payments when unpaused', async function () {
      this.crowdsale.should.exist;
      this.token.should.exist;

      await this.crowdsale.unpause();
      await this.crowdsale.send(ether(1)).should.be.fulfilled;
    });

    it('should not accept payments when paused', async function () {
      this.crowdsale.should.exist;
      this.token.should.exist;

      await this.crowdsale.unpause();
      await this.crowdsale.send(ether(1)).should.be.fulfilled;
      await this.crowdsale.pause();
      try {
          await this.crowdsale.send(ether(1));
          assert.fail('Expected reject not received');
      } catch (error) {
        assert(error.message.search('invalid opcode') > 0, 'Wrong error message received: ' + error.message);
      }
    });

    it('should fail when sending 0 ethers', async function () {
      this.crowdsale.should.exist;

      await this.crowdsale.unpause();
      try {
          await this.crowdsale.send(ether(0));
          assert.fail('Expected reject not received');
      } catch (error) {
        assert(error.message.search('invalid opcode') > 0, 'Wrong error message received: ' + error.message);
      }
    });
  });

  describe('receiving tokens', function () {
    it('should reveive correct amount (11500) of tokens when sending 1 ether for the 1\'st wave', async function () {
      this.crowdsale.should.exist;
      await this.crowdsale.unpause();
      await this.crowdsale.buyTokens(investor, { value: ether(1), from: purchaser });
      const balance = await this.token.balanceOf(investor);
      balance.should.be.bignumber.equal(11500e18);
    });

    it('should reveive correct amount (11000) of tokens when sending 1 ether for the 2\'nd wave', async function () {
      this.crowdsale.should.exist;
      await this.crowdsale.unpause();
      await this.crowdsale.buyTokens(wallet, { value: ether(4400), from: purchaser });

      await this.crowdsale.buyTokens(investor, { value: ether(1), from: purchaser });
      const balance = await this.token.balanceOf(investor);
      balance.should.be.bignumber.equal(11000e18);
    });
  });

  describe('finalize', function () {
    it('should allow finalize when paused', async function () {
      this.crowdsale.should.exist;
      await this.crowdsale.finalize();
    });

    it('should transfer all tokens to wallet when finalized', async function () {
      this.crowdsale.should.exist;
      await this.crowdsale.finalize();
      const balance = await this.token.balanceOf(wallet);
      balance.should.be.bignumber.equal(250e24);
    });

    it('should transfer all left tokens to wallet when finalized', async function () {
      this.crowdsale.should.exist;
      await this.crowdsale.unpause();
      await this.crowdsale.buyTokens(investor, { value: ether(5), from: purchaser });
      await this.crowdsale.pause();
      await this.crowdsale.finalize();
      const balance = await this.token.balanceOf(wallet);
      balance.should.be.bignumber.equal(249.9425e24);
    });


    it('should reassign ownership to wallet when finalized', async function () {
      this.crowdsale.should.exist;
      await this.crowdsale.finalize();
      let owner = await this.token.owner();
      owner.should.be.equal(wallet);
    });

    it('should not allow finalize when not paused', async function () {
      this.crowdsale.should.exist;
      await this.crowdsale.unpause();
      try {
          await this.crowdsale.finalize();
          assert.fail('Expected reject not received');
      } catch (error) {
        assert(error.message.search('invalid opcode') > 0, 'Wrong error message received: ' + error.message);
      }
    });
  });
});

function ether (n) {
  return new web3.BigNumber(web3.toWei(n, 'ether'));
}
