// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;


abstract contract GasRefunds {

    event Refunded(address receiver, uint256 amount, bool successful);

    modifier refundGas() {
        uint256 _gasbefore = gasleft();
        _;
        // TODO: How can I not care about the return value something? I think the notaiton  is _, right?
        uint256 refundAmount = (_gasbefore - gasleft()) * tx.gasprice;
        (bool sent, bytes memory something) = payable(msg.sender).call{value: refundAmount}("");
        emit Refunded(msg.sender, refundAmount, sent);
    }

}