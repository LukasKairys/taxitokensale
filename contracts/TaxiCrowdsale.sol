pragma solidity ^0.4.18;

import 'zeppelin-solidity/contracts/crowdsale/distribution/FinalizableCrowdsale.sol';
import "zeppelin-solidity/contracts/crowdsale/emission/MintedCrowdsale.sol";
import 'zeppelin-solidity/contracts/token/ERC20/MintableToken.sol';
import './TaxiToken.sol';

contract TaxiCrowdsale is FinalizableCrowdsale, MintedCrowdsale {

  uint256 private constant TOKENS_RATE_CHANGE_STEP = 50000000 * 10**18;
  uint256 private constant INIT_RATE = 11500 * 10**18;
  uint256 private constant MIN_RATE = 10000 * 10**18;
  uint256 private constant RATE_STEP = 500 * 10**18;

  uint256 private leftovers = 250000000 * 10**18;
  uint256 private toSellTillNextStep = TOKENS_RATE_CHANGE_STEP;

  function TaxiCrowdsale(address _wallet, TaxiToken _token, uint256 _openingTime, uint256 _closingTime) public
    Crowdsale(INIT_RATE, _wallet, _token)
    TimedCrowdsale(_openingTime, _closingTime) {
  }

  function _preValidatePurchase(address _beneficiary, uint256 _weiAmount) internal {
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

    while (_tokens > 0 && leftovers > 0 && _weiLeft > 0) {
      if (toSellTillNextStep.sub(_tokens) < 0 && leftovers.sub(_tokens) > 0) {
          _tokens = _tokens.sub(toSellTillNextStep);
          leftovers = leftovers.sub(toSellTillNextStep);

          _tokensToSend = _tokensToSend.add(toSellTillNextStep);
          _weiReq = toSellTillNextStep.div(rate);
          _weiLeft = _weiLeft.sub(_weiReq);

          toSellTillNextStep = TOKENS_RATE_CHANGE_STEP;
          rate = rate.sub(RATE_STEP);
          if (rate < MIN_RATE) {
            rate = MIN_RATE;
          }
      } else {
        uint256 _leftovers = leftovers;
        if (_tokens < leftovers) {
          _leftovers = _tokens;
        }
        _tokens = _tokens.sub(_leftovers);
        leftovers = leftovers.sub(_leftovers);

        _tokensToSend = _tokensToSend.add(_leftovers);
        _weiReq = _leftovers.div(rate);
        _weiLeft = _weiLeft.sub(_weiReq);
      }
    }

    //TODO: check if this really transfers as required and msg.value changes and if forwardFunds needed
    if (_weiLeft > 0) {
      weiRaised = weiRaised.sub(_weiLeft);
      msg.sender.transfer(_weiLeft);
    }

    return _tokensToSend;

  }

  function finalization() internal {
    if (leftovers > 0) {
      wallet.transfer(leftovers);
    }
  }

}
