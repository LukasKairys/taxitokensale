pragma solidity ^0.4.18;

import 'zeppelin-solidity/contracts/token/ERC20/CappedToken.sol';

contract TaxiToken is CappedToken { 

  string public constant name = "TaxiToken";
  string public constant symbol = "TAXI";
  uint8 public constant decimals = 18;

}
