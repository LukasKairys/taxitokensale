pragma solidity ^0.4.18;

import 'zeppelin-solidity/contracts/crowdsale/distribution/FinalizableCrowdsale.sol';
import "zeppelin-solidity/contracts/crowdsale/emission/MintedCrowdsale.sol";
import 'zeppelin-solidity/contracts/token/ERC20/MintableToken.sol';
import 'zeppelin-solidity/contracts/lifecycle/Pausable.sol';
import './TaxiToken.sol';

/*
  Taxi crowdsale is Pausable contract it is paused on init
  and may be paused any time in the process. While it is paused
  it can finalized meaning all left tokens will be assigned to owner wallet
*/
contract TaxiCrowdsale is MintedCrowdsale, Pausable {

  uint256 private constant TOKENS_RATE_CHANGE_STEP = 50000000 * 10**18;
  uint256 private constant INIT_RATE = 11500 * 10**18;
  uint256 private constant MIN_RATE = 10000 * 10**18;
  uint256 private constant RATE_STEP = 500 * 10**18;

  uint256 private leftovers = 250000000 * 10**18;
  uint256 private toSellTillNextStep = TOKENS_RATE_CHANGE_STEP;

  bool public isFinalized = false;

  event Finalized();

  modifier notFinished() {
    require(leftovers > 0);
    require(!isFinalized);
    _;
  }

  function TaxiCrowdsale(address _wallet, TaxiToken _token) public
    Crowdsale(INIT_RATE, _wallet, _token) {
      paused = true;
  }

  function _preValidatePurchase(address _beneficiary, uint256 _weiAmount) whenNotPaused notFinished internal {
    super._preValidatePurchase(_beneficiary, _weiAmount);
    require(leftovers > 0);
  }

  function _getTokenAmount(uint256 _weiAmount) internal view returns (uint256) {
    uint256 _tokens = _weiAmount.mul(rate);

    if (toSellTillNextStep.sub(_tokens) > 0 && leftovers.sub(_tokens) > 0) {
      toSellTillNextStep = toSellTillNextStep.sub(_tokens);
      leftovers = leftovers.sub(_tokens);
      return _tokens;
    }

    uint256 _weiReq = 0;
    uint256 _weiLeft = _weiAmount;
    uint256 _tokensToSend = 0;

    while (leftovers > 0 && _weiLeft > 0) {
      uint256 _stepTokens = 0;

      if (toSellTillNextStep.sub(_tokens) < 0) {
          _stepTokens = toSellTillNextStep;
          toSellTillNextStep = TOKENS_RATE_CHANGE_STEP;

          rate = rate.sub(RATE_STEP);
          if (rate < MIN_RATE) {
            rate = MIN_RATE;
          }
      } else if (leftovers.sub(_tokens) > 0) {
        _stepTokens = _tokens;
        toSellTillNextStep = toSellTillNextStep.sub(_tokens);
      } else {
        _stepTokens = leftovers;
        toSellTillNextStep = toSellTillNextStep.sub(leftovers);
      }

      _tokensToSend = _tokensToSend.add(_stepTokens);
      _weiReq = _stepTokens.div(rate);
      _weiAmount = _weiAmount.sub(_weiReq);
      leftovers = leftovers.sub(_stepTokens);

      _tokens = _weiAmount.mul(rate);
    }

    //TODO: check if this really transfers as required and msg.value changes and if forwardFunds needed
    if (_weiLeft > 0) {
      weiRaised = weiRaised.sub(_weiLeft);
      msg.sender.transfer(_weiLeft);
    }

    return _tokensToSend;

  }

  function finalize() onlyOwner whenPaused public {
    require(!isFinalized);

    finalization();
    Finalized();

    isFinalized = true;
  }

  function finalization() internal {
    require(MintableToken(token).mint(wallet, leftovers));
  }
}
