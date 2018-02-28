pragma solidity ^0.4.18;

import "zeppelin-solidity/contracts/crowdsale/emission/MintedCrowdsale.sol";
import 'zeppelin-solidity/contracts/lifecycle/Pausable.sol';
import './TaxiToken.sol';

/*
  Taxi crowdsale is Pausable contract it is paused on init
  and may be paused any time in the process. While it is paused
  it can finalized meaning all left tokens will be assigned to owner wallet
*/
contract TaxiCrowdsale is MintedCrowdsale, Pausable {
  using SafeMath for uint256;

  uint256 private constant TOKENS_RATE_CHANGE_STEP = 50 * 10**24;
  uint256 private constant INIT_RATE = 11500;
  uint256 private constant MIN_RATE = 10000;
  uint256 private constant RATE_STEP = 500;

  uint256 private leftovers = 250 * 10**24;
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

  function _preValidatePurchase(address _beneficiary, uint256 _weiAmount) notFinished whenNotPaused internal {
    super._preValidatePurchase(_beneficiary, _weiAmount);
    require(_weiAmount > 0);
  }

  function _getTokenAmount(uint256 _weiAmount) internal view returns (uint256) {
    uint256 _tokens = _weiAmount.mul(rate);
    if (toSellTillNextStep > _tokens && leftovers > _tokens) {
      toSellTillNextStep = toSellTillNextStep.sub(_tokens);
      leftovers = leftovers.sub(_tokens);
      return _tokens;
    }

    uint256 _weiReq = 0;
    uint256 _tokensToSend = 0;

    while (leftovers > 0 && _weiAmount > 0) {
      uint256 _stepTokens = 0;

      if (toSellTillNextStep < _tokens) {
          _stepTokens = toSellTillNextStep;
          toSellTillNextStep = TOKENS_RATE_CHANGE_STEP;
          _weiReq = _stepTokens.div(rate);
          _weiAmount = _weiAmount.sub(_weiReq);

          rate = rate.sub(RATE_STEP);
          if (rate < MIN_RATE) {
            rate = MIN_RATE;
          }
      } else if (leftovers > _tokens) {
        _stepTokens = _tokens;
        toSellTillNextStep = toSellTillNextStep.sub(_tokens);
        _weiReq = _stepTokens.div(rate);
        _weiAmount = _weiAmount.sub(_weiReq);
      } else {
        _stepTokens = leftovers;
        toSellTillNextStep = toSellTillNextStep.sub(leftovers);
        _weiReq = _stepTokens.div(rate);
        _weiAmount = _weiAmount.sub(_weiReq);
      }

      _tokensToSend = _tokensToSend.add(_stepTokens);
      leftovers = leftovers.sub(_stepTokens);

      _tokens = _weiAmount.mul(rate);
    }

    //TODO: check if this really transfers as required and msg.value changes and if forwardFunds needed
    //TODO: cant set raisedWei here - since it might be 0 here. Need to think of other way.
    if (_weiAmount > 0) {
      msg.sender.transfer(_weiAmount);
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
    require(TaxiToken(token).mint(wallet, leftovers));
    TaxiToken(token).transferOwnership(wallet);
  }
}
