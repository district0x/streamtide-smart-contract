// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

struct Donation {
    address receiver;
    uint256 amount;
}

contract MVPCLR is Ownable {
    uint256 public roundStart;
    uint256 public roundDuration;
    uint256 public patronCount = 0;
    uint256 public id = 0;


    address[] public admins;
    

    mapping(address => bool) public isAdmin;
    
    mapping(address => uint256) public supporters;
    mapping(uint256 => address) public patrons;

    Donation[] public donations;
    int256 index_of_last_processed_donation = -1;

    event RoundStarted(uint256 roundStart, uint256 roundDuration);
    event PatronAdded(
        address addr,
        bytes32 data,
        string link,
        string ipfsHash,
        uint256 index
    );
    event Donate(
        address origin,
        address sender,
        uint256 value,
        uint256 index,
        uint256 id
    );

    event MatchingPoolDonation(address sender, uint256 value);
    event Distribute(address to, uint256 amount);

    function openRound() public onlyAdmin {
        require(roundDuration == 0, "Round is already open");
        roundDuration = 30*24*60*60; // 1 month 
        roundStart = getBlockTimestamp();
        emit RoundStarted(roundStart, roundDuration);
    }

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
        emit RoundStarted(roundStart, roundDuration);
    }

    function addAdmin(address _admin) public onlyOwner {
        admins.push(_admin);
        isAdmin[_admin] = true;
    
    }

    function removeAdmin(address _admin) public onlyOwner {
    require(isAdmin[_admin], "Admin not found"); // check if the address is an admin
    uint256 adminIndex;
    for (uint256 i = 0; i < admins.length; i++) {
        if (admins[i] == _admin) {
            adminIndex = i;
            break;
        }
    }
    delete admins[adminIndex];
    delete isAdmin[_admin];
    }

    function getBlockTimestamp() public view returns (uint256) {
        return block.timestamp;
    }

    function addPatron(
        address payable addr,
        bytes32 data,
        string memory link,
        string memory ipfsHash
    ) public onlyAdmin {
        patrons[patronCount] = addr;
        emit PatronAdded(addr, data, link, ipfsHash, patronCount);
        patronCount = patronCount + 1;
    }

    function donate(uint256[] memory patron_indexes, uint256[] memory amounts) public payable {
        uint256 total_amount = 0;
        for(uint256 i = 0; i < patron_indexes.length; i++) {
            uint256 patron_index = patron_indexes[i];
            uint256 amount = amounts[i];
            total_amount = total_amount + amount;
            require(patron_index < patronCount, "CLR:donate - Not a valid recipient");
            donations.push(Donation(patrons[patron_index], amount));
            emit Donate(tx.origin, _msgSender(), amount, patron_index, id);
        }
        require(total_amount == msg.value, "amount sent does not match sum of donations");
        supporters[_msgSender()] = supporters[_msgSender()] + total_amount;
        // add tip amount in investors mapping
    }

    function distribute(uint256 _maxProcess) external onlyAdmin {
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
