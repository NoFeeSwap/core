# Copyright 2025, NoFeeSwap LLC - All rights reserved.
import pytest
import brownie
from brownie import accounts, StorageWrapper
from Nofee import logTest, address0
from Tag_test import tag0, tag2

accruedMax = (1 << 231) - 1

address1 = '0x0000000000000000000000000000000000000001'
address2 = '0xF00FF00FF00FF00FF00FF00FF00FF00FF00FF00F'
address3 = '0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF'

value0 = 0x0000000000000000000000000000000000000000000000000000000000000000
value1 = 0x0000000000000000000000000000000000000000000000000000000000000001
value2 = 0xF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00F
value3 = 0x8FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
value4 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF

portion0 = 0x000000000000
portion1 = 0x400000000000
portion2 = 0x800000000000
portion3 = 0xFFFFFFFFFFFF

balance0 = 0x00000000000000000000000000000000
balance1 = 0x00000000000000000000000000000001
balance2 = 0xF00FF00FF00FF00FF00FF00FF00FF00F
balance3 = 0x8FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
balance4 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
balance5 = 0 - 0x00000000000000000000000000000001
balance6 = 0 - 0xF00FF00FF00FF00FF00FF00FF00FF00F
balance7 = 0 - 0x8FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
balance8 = 0 - 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF

storageSlot0 = 0x0000000000000000000000000000000000000000000000000000000000000000
storageSlot1 = 0x0000000000000000000000000000000000000000000000000000000000000001
storageSlot2 = 0xF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00F
storageSlot3 = 0x8FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
storageSlot4 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF

ratio0 = 0x000000
ratio1 = 0x400000
ratio2 = 0x800000
ratio3 = 0xFFFFFF

accrued0 = 0x0000000000000000000000000000000000000000000000000000000000000000
accrued1 = 0x0000000000000000000000000000000080000000000000000000000000000000
accrued2 = 0x7807F807F807F807F807F807F807F80780000000000000000000000000000000
accrued3 = 0x47FFFFFFFFFFFFFFFFFFFFFFFFFFFFFF80000000000000000000000000000000
accrued4 = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF80000000000000000000000000000000

logPrice0 = 0x0000000000000000
logPrice1 = 0x0000000000000001
logPrice2 = 0xF00FF00FF00FF00F
logPrice3 = 0x8FFFFFFFFFFFFFFF
logPrice4 = 0xFFFFFFFFFFFFFFFF

pointer0 = 0x0000
pointer1 = 0xF00F
pointer2 = 0xFFFF

integral0 = 0x000000000000000000000000000000000000000000000000000000
integral1 = 0xFFF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00F
integral2 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF

curve0 = 0x0550550550550550550550550550550550550550550550550550550550550550
curve1 = 0x1001001001001001001001001001001001001001001001001001001001001001
curve2 = 0x7CC77CC77CC77CC77CC77CC77CC77CC77CC77CC77CC77CC77CC77CC77CC77CC7
curve3 = 0x8BB88BB88BB88BB88BB88BB88BB88BB88BB88BB88BB88BB88BB88BB88BB88BB8
curve4 = 0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA

@pytest.fixture(autouse=True)
def wrapper(fn_isolation):
    return StorageWrapper.deploy({'from': accounts[0]})

@pytest.mark.parametrize('currentBalance', [balance0, balance1, balance2, balance4])
@pytest.mark.parametrize('currentIsOperator', [False, True])
@pytest.mark.parametrize('currentAllowance', [value0, value2, value4])
@pytest.mark.parametrize('owner', [address0, address1, address3])
@pytest.mark.parametrize('tag', [tag0, tag2])
@pytest.mark.parametrize('amount', [balance0, balance1, balance2, balance4, value0, value1, value2, value3])
def test_decrementBalance(wrapper, currentBalance, currentIsOperator, currentAllowance, owner, tag, amount, request, worker_id):
    logTest(request, worker_id)
    
    # Check if single balances are decremented correctly.
    if not(currentIsOperator) and (amount > currentAllowance):
        with brownie.reverts('InsufficientPermission: ' + accounts[0].address.lower() + ', ' + str(tag)):
            tx = wrapper._decrementBalance(currentBalance, currentIsOperator, currentAllowance, owner, tag, amount)
    elif (amount > currentBalance):
        with brownie.reverts('InsufficientBalance: ' + owner.lower() + ', ' + str(tag)):
            tx = wrapper._decrementBalance(currentBalance, currentIsOperator, currentAllowance, owner, tag, amount)
    else:
        tx = wrapper._decrementBalance(currentBalance, currentIsOperator, currentAllowance, owner, tag, amount)
        newBalance, newAllowance = tx.return_value
        assert newBalance == currentBalance - amount
        if not(currentIsOperator) and (currentAllowance != ((2 ** 256) - 1)):
            assert newAllowance == currentAllowance - amount
        else:
            assert newAllowance == currentAllowance
        assert tx.events['Transfer']['from'] == owner
        assert tx.events['Transfer']['to'] == address0
        assert tx.events['Transfer']['tag'] == tag
        assert tx.events['Transfer']['amount'] == amount