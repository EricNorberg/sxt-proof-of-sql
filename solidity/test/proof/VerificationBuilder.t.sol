// SPDX-License-Identifier: UNLICENSED
// This is licensed under the Cryptographic Open Software License 1.0
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import "../../src/base/Constants.sol";
import {VerificationBuilder} from "../../src/proof/VerificationBuilder.sol";

library VerificationBuilderTestHelper {
    function setChallenges(uint256 builderPtr, uint256[] memory challenges) internal pure {
        uint256 challengePtr;
        assembly {
            challengePtr := add(challenges, WORD_SIZE)
        }
        VerificationBuilder.__setChallenges(builderPtr, challengePtr, challenges.length);
    }
}

contract VerificationBuilderTest is Test {
    function testFuzzAllocateBuilder(uint256[] memory) public pure {
        // Note: the extra parameter is simply to make the free pointer location unpredictable.
        uint256 expectedBuilder;
        assembly {
            expectedBuilder := mload(FREE_PTR)
        }
        assert(VerificationBuilder.__allocate() == expectedBuilder);
        uint256 freePtr;
        assembly {
            freePtr := mload(FREE_PTR)
        }
        assert(freePtr == expectedBuilder + VERIFICATION_BUILDER_SIZE);
    }

    function testSetChallenges() public pure {
        uint256 builderPtr = VerificationBuilder.__allocate();
        VerificationBuilder.__setChallenges(builderPtr, 0xABCD, 0x1234);
        uint256 head;
        uint256 tail;
        assembly {
            head := mload(add(builderPtr, CHALLENGE_HEAD_OFFSET))
            tail := mload(add(builderPtr, CHALLENGE_TAIL_OFFSET))
        }
        assert(head == 0xABCD);
        assert(tail == 0xABCD + WORD_SIZE * 0x1234);
    }

    function testFuzzSetChallenges(uint256[] memory, uint256 challengePtr, uint64 challengeLength) public pure {
        vm.assume(challengePtr < 2 ** 64);
        vm.assume(challengeLength < 2 ** 64);
        uint256 builderPtr = VerificationBuilder.__allocate();
        VerificationBuilder.__setChallenges(builderPtr, challengePtr, challengeLength);
        uint256 head;
        uint256 tail;
        assembly {
            head := mload(add(builderPtr, CHALLENGE_HEAD_OFFSET))
            tail := mload(add(builderPtr, CHALLENGE_TAIL_OFFSET))
        }
        assert(head == challengePtr);
        assert(tail == challengePtr + WORD_SIZE * challengeLength);
    }

    function testSetAndConsumeZeroChallenges() public {
        uint256[] memory challenges = new uint256[](0);
        uint256 builderPtr = VerificationBuilder.__allocate();
        VerificationBuilderTestHelper.setChallenges(builderPtr, challenges);
        vm.expectRevert(Errors.TooFewChallenges.selector);
        VerificationBuilder.__consumeChallenge(builderPtr);
    }

    function testSetAndConsumeOneChallenge() public {
        uint256[] memory challenges = new uint256[](1);
        challenges[0] = 0x12345678;
        uint256 builderPtr = VerificationBuilder.__allocate();
        VerificationBuilderTestHelper.setChallenges(builderPtr, challenges);
        assert(VerificationBuilder.__consumeChallenge(builderPtr) == 0x12345678);
        vm.expectRevert(Errors.TooFewChallenges.selector);
        VerificationBuilder.__consumeChallenge(builderPtr);
    }

    function testSetAndConsumeChallenges() public {
        uint256[] memory challenges = new uint256[](3);
        challenges[0] = 0x12345678;
        challenges[1] = 0x23456789;
        challenges[2] = 0x3456789A;
        uint256 builderPtr = VerificationBuilder.__allocate();
        VerificationBuilderTestHelper.setChallenges(builderPtr, challenges);
        assert(VerificationBuilder.__consumeChallenge(builderPtr) == 0x12345678);
        assert(VerificationBuilder.__consumeChallenge(builderPtr) == 0x23456789);
        assert(VerificationBuilder.__consumeChallenge(builderPtr) == 0x3456789A);
        vm.expectRevert(Errors.TooFewChallenges.selector);
        VerificationBuilder.__consumeChallenge(builderPtr);
    }

    function testFuzzSetAndConsumeChallenges(uint256[] memory, uint256[] memory challenges) public {
        uint256 builderPtr = VerificationBuilder.__allocate();
        VerificationBuilderTestHelper.setChallenges(builderPtr, challenges);
        uint256 challengesLength = challenges.length;
        for (uint256 i = 0; i < challengesLength; ++i) {
            assert(VerificationBuilder.__consumeChallenge(builderPtr) == challenges[i]);
        }
        vm.expectRevert(Errors.TooFewChallenges.selector);
        VerificationBuilder.__consumeChallenge(builderPtr);
    }
}
