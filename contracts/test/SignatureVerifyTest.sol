pragma solidity ^0.5.2;

/*
 * This is a contract used for testing the ECVerify library and ecrecover behaviour.
 */

import "raiden/lib/ECVerify.sol";

contract SignatureVerifyTest {
    function verify(bytes32 _message_hash, bytes memory _signed_message)
        pure
        public
        returns (address signer)
    {
        // Derive address from signature
        signer = ECVerify.ecverify(_message_hash, _signed_message);
    }

    function verifyEcrecoverOutput(bytes32 hash, bytes32 r, bytes32 s, uint8 v)
        pure
        public
        returns (address signature_address)
    {
        signature_address = ecrecover(hash, v, r, s);
    }
}
