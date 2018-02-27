pragma solidity ^0.4.18;

import 'zeppelin-solidity/contracts/token/ERC20/CappedToken.sol';
import 'zeppelin-solidity/contracts/token/ERC20/PausableToken.sol';

/*
  TaxiToken is PausableToken and on the creation it is paused.
  It is made so because you don't want token to be transferable etc,
  while your ico is not over.
*/
contract TaxiToken is CappedToken, PausableToken {

  uint256 private constant TOKEN_CAP = 500 * 10**24;

  string public constant name = "TaxiToken";
  string public constant symbol = "TAXI";
  uint8 public constant decimals = 18;

  function TaxiToken() public CappedToken(TOKEN_CAP) {
    paused = true;
  }
}
