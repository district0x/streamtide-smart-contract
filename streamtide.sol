// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

struct Donation {
    address receiver;
    uint256 amount;
}

contract MVPCLR is Ownable {
    
    event AdminAdded(address _admin);
    event AdminRemoved(address _admin);
    event BlacklistedAdded(address _blacklisted);
    event BlacklistedRemoved(address _blacklisted);

    event PatronAdded(address addr);

    event RoundStarted(uint256 roundStart, uint256 roundId, uint256 roundDuration);
    event MatchingPoolDonation(address sender, uint256 value);
    event Distribute(address to, uint256 amount);

    event Donate(
        address origin,
        address sender,
        uint256 value,
        address patronAddress,
        uint256 id
    );

    uint256 public roundStart;
    uint256 public roundDuration;
    uint256 public patronCount;
    uint256 id;

    mapping(address => bool) public isAdmin;
    mapping(address => bool) public isPatron;
    mapping(address => bool) public isBlacklisted;

    Donation[] public donations;
    int256 index_of_last_processed_donation = -1;
    
    function closeRound() public onlyAdmin {
        roundDuration = 0;
    }

    function roundIsClosed() public view returns (bool) {
        return roundDuration != 0 && roundStart + roundDuration <= getBlockTimestamp();
    }


    function startRound(uint256 _roundDuration) public onlyAdmin {
        id = id +1;
        require(_roundDuration < 31536000, "MVPCLR: round duration too long");
        roundDuration = _roundDuration;
        roundStart = getBlockTimestamp();
        emit RoundStarted(roundStart, id, roundDuration);
    }

    function addAdmin(address _admin) public onlyOwner {
        isAdmin[_admin] = true;
        emit AdminAdded(_admin);
    }

    function removeAdmin(address _admin) public onlyOwner {
        require(isAdmin[_admin], "Admin not found"); // check if the address is an admin
        delete isAdmin[_admin];
        emit AdminRemoved(_admin);
    }

    function getBlockTimestamp() public view returns (uint256) {
        return block.timestamp;
    }

    function addBlacklisted(address _address) public onlyAdmin {
        isBlacklisted[_address] = true;
        emit BlacklistedAdded(_address);
    }


    function removeBlacklisted(address _address) public onlyAdmin {
        require(isBlacklisted[_address], "Address not blacklisted");
        delete isBlacklisted[_address];
        emit BlacklistedRemoved(_address);
    }

    function addPatron(address payable addr) public onlyAdmin {
        require(!isBlacklisted[addr], "Patron address is blacklisted");
        isPatron[addr] = true;
        emit PatronAdded(addr);
        patronCount = patronCount + 1;
    }

    function donate(address[] memory patronAddresses, uint256[] memory amounts) public payable {
        require(patronAddresses.length == amounts.length, "CLR:donate - Mismatch between number of patrons and amounts");
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < patronAddresses.length; i++) {
            address patronAddress = patronAddresses[i];
            uint256 amount = amounts[i];
            totalAmount += amount;
            require(!isBlacklisted[_msgSender()], "Sender address is blacklisted");
            require(isPatron[patronAddress], "CLR:donate - Not a valid recipient");
            donations.push(Donation(patronAddress, amount));
            emit Donate(tx.origin, _msgSender(), amount, patronAddress, id);
        }
         require(totalAmount <= msg.value, "CLR:donate - Total amount donated is greater than the value sent");
    }

    function distribute(uint256 _maxProcess) external onlyAdmin {
        require(roundIsClosed(), "Round is still open");
        uint256 processed = 0;
        while(index_of_last_processed_donation + int256(processed) < int256(donations.length)-1 && processed < _maxProcess) {
            Donation memory donation = donations[uint256(index_of_last_processed_donation+1)+processed];
            payable(donation.receiver).transfer(donation.amount);
            emit Distribute(donation.receiver, donation.amount);
            processed = processed + 1;
        }
        index_of_last_processed_donation += int256(processed);

    }
    
    // receive donation for the matching pool
    receive() external payable {
        require(
            roundStart == 0 || getBlockTimestamp() < roundStart + roundDuration,
            "CLR:receive closed"
        );
        emit MatchingPoolDonation(_msgSender(), msg.value);
    }

    modifier onlyAdmin() {
    require(isAdmin[msg.sender] == true, "Not an admin");
    _;
    }
}
