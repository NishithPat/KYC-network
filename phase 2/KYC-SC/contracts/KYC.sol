// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

contract KYC {
    struct Customer {
        string userName;
        string data;
        bool kycStatus;
        uint256 downvotes;
        uint256 upvotes;
        address bank;
    }

    struct Bank {
        string name;
        address ethAddress;
        uint256 complaintsReported;
        uint256 KYC_count;
        bool allowedToVote;
        string regNumber;
    }

    struct KYC_request {
        string userName;
        string customerData;
        address bankAddress;
    }

    address admin;
    mapping(string => Customer) customers; //customers' list
    mapping(address => Bank) banks; //list of banks
    uint256 totalBanks; //variable to keep track of totalBanks in the System
    mapping(string => KYC_request) requests; //list of KYC requests

    mapping(string => mapping(address => bool)) hasVotedforCustomer; //mapping to ensure banks can only vote for a customer once
    mapping(address => mapping(address => bool)) hasVotedForBank; //mapping to ensure banks can report other banks only once

    constructor() {
        //only called once, so admin is set to the address
        //that deploys the contract
        admin = msg.sender;
    }

    function addBank(
        string memory _bankName,
        address _bankAddress,
        string memory _regNumber
    ) public {
        require(msg.sender == admin, "only admin can add banks");
        require(_bankAddress != address(0), "address of a bank cannot be 0");
        require(
            banks[_bankAddress].ethAddress != _bankAddress,
            "the bank already exists"
        );

        //bank initialization
        banks[_bankAddress].name = _bankName;
        banks[_bankAddress].ethAddress = _bankAddress;
        banks[_bankAddress].complaintsReported = 0;
        banks[_bankAddress].KYC_count = 0;
        banks[_bankAddress].allowedToVote = true;
        banks[_bankAddress].regNumber = _regNumber;

        //increment
        totalBanks += 1;
    }

    function isBankAllowedToVote(address _bankAddress, bool value) public {
        require(msg.sender == admin, "only admin can call this function");
        require(_bankAddress != address(0), "address of a bank cannot be 0");
        require(
            banks[_bankAddress].ethAddress == _bankAddress,
            "the bank does not exist exist"
        );

        banks[_bankAddress].allowedToVote = value;
    }

    function removeBank(address _bankAddress) public {
        require(msg.sender == admin, "only admin can remove banks");
        require(_bankAddress != address(0), "address of a bank cannot be 0");
        require(
            banks[_bankAddress].ethAddress == _bankAddress,
            "the bank does not exist"
        );

        //decrement
        totalBanks -= 1;
        delete banks[_bankAddress];
    }

    function addRequest(string memory _userName, string memory _customerData)
        public
    {
        require(
            requests[_userName].bankAddress == address(0),
            "Customer is already present in the KYC requests"
        );
        require(
            banks[msg.sender].ethAddress != address(0),
            "only a bank can call the function"
        );

        requests[_userName].userName = _userName;
        requests[_userName].customerData = _customerData;
        requests[_userName].bankAddress = msg.sender;

        //increase in KYC_count after request initialization
        banks[msg.sender].KYC_count += 1;
    }

    function addCustomer(string memory _userName, string memory _customerData)
        public
    {
        //only after KYC_request verification, Customer is added to the customers' list
        require(
            customers[_userName].bank == address(0),
            "Customer is already present in the customers' list, please call modifyCustomer to edit the customer data"
        );
        require(
            requests[_userName].bankAddress != address(0),
            "Customer is not present in the KYC requests"
        );
        require(
            banks[msg.sender].ethAddress != address(0),
            "only a bank can call the function"
        );

        customers[_userName].userName = _userName;
        customers[_userName].data = _customerData;
        customers[_userName].kycStatus = false;
        customers[_userName].downvotes = 0;
        customers[_userName].upvotes = 0;

        //bank in customer struct is the bank that initialized the customer initially for KYC
        customers[_userName].bank = requests[_userName].bankAddress;
    }

    function removeRequests(string memory _userName) public {
        require(
            requests[_userName].bankAddress != address(0),
            "Customer is not present in the KYC requests"
        );
        require(
            banks[msg.sender].ethAddress != address(0),
            "only a bank can call the function"
        );

        delete requests[_userName];
    }

    function viewCustomer(string memory _userName)
        public
        view
        returns (
            string memory,
            string memory,
            bool,
            uint256,
            uint256,
            address
        )
    {
        require(
            customers[_userName].bank != address(0),
            "Customer is not present in the database"
        );
        require(
            banks[msg.sender].ethAddress != address(0),
            "only a bank can call the function"
        );

        return (
            customers[_userName].userName,
            customers[_userName].data,
            customers[_userName].kycStatus,
            customers[_userName].downvotes,
            customers[_userName].upvotes,
            customers[_userName].bank
        );
    }

    function upvoteCustomer(string memory _userName) public {
        require(
            customers[_userName].bank != address(0),
            "Customer is not present in the database"
        );
        require(
            banks[msg.sender].ethAddress != address(0),
            "only a bank can call the function"
        );
        require(banks[msg.sender].allowedToVote, "bank is not allowed to vote");
        require(
            !hasVotedforCustomer[_userName][msg.sender],
            "the bank has already voted for the customer"
        );

        customers[_userName].upvotes += 1;
        hasVotedforCustomer[_userName][msg.sender] = true; //only one vote for a bank

        //check for number of upvotes to number of downvotes
        //if upvotes are greater and upvotes + downvotes == totalBanks, then kycStatus is true
        if (
            customers[_userName].upvotes + customers[_userName].downvotes ==
            totalBanks &&
            customers[_userName].upvotes > customers[_userName].downvotes
        ) {
            customers[_userName].kycStatus = true;
        }

        //if number of downvotes is greater than a third of all the banks,
        //kycStatus is set to false
        if (customers[_userName].downvotes > totalBanks / 3) {
            customers[_userName].kycStatus = false;
        }
    }

    function downvoteCustomer(string memory _userName) public {
        require(
            customers[_userName].bank != address(0),
            "Customer is not present in the database"
        );
        require(
            banks[msg.sender].ethAddress != address(0),
            "only a bank can call the function"
        );
        require(banks[msg.sender].allowedToVote, "bank is not allowed to vote");
        require(
            !hasVotedforCustomer[_userName][msg.sender],
            "the bank has already voted for the customer"
        );

        customers[_userName].downvotes += 1;
        hasVotedforCustomer[_userName][msg.sender] = true; //only one vote for a bank

        //check for number of upvotes to number of downvotes
        //if upvotes are greater and upvotes + downvotes == totalBanks, then kycStatus is true
        if (
            customers[_userName].upvotes + customers[_userName].downvotes ==
            totalBanks &&
            customers[_userName].upvotes > customers[_userName].downvotes
        ) {
            customers[_userName].kycStatus = true;
        }

        //if number of downvotes is greater than a third of all the banks,
        //kycStatus is set to false
        if (customers[_userName].downvotes > totalBanks / 3) {
            customers[_userName].kycStatus = false;
        }
    }

    function modifyCustomer(
        string memory _userName,
        string memory _newcustomerData
    ) public {
        require(
            customers[_userName].bank != address(0),
            "Customer is not present in the database"
        );
        require(
            banks[msg.sender].ethAddress != address(0),
            "only a bank can call the function"
        );

        customers[_userName].data = _newcustomerData;
        customers[_userName].upvotes = 0;
        customers[_userName].downvotes = 0;

        //as per the problem statement, once modified, the customer is deleted from KYC_requests list
        delete requests[_userName];
    }

    function getBankComplaints(address _bankAddress)
        public
        view
        returns (uint256)
    {
        require(
            banks[_bankAddress].ethAddress != address(0),
            "bank does not exist"
        );
        require(
            banks[msg.sender].ethAddress != address(0),
            "only a bank can call the function"
        );

        return banks[_bankAddress].complaintsReported;
    }

    function viewBankDetails(address _bankAddress)
        public
        view
        returns (
            string memory,
            address,
            uint256,
            uint256,
            bool,
            string memory
        )
    {
        require(
            banks[_bankAddress].ethAddress != address(0),
            "bank does not exist"
        );
        require(
            banks[msg.sender].ethAddress != address(0),
            "only a bank can call the function"
        );

        return (
            banks[_bankAddress].name,
            banks[_bankAddress].ethAddress,
            banks[_bankAddress].complaintsReported,
            banks[_bankAddress].KYC_count,
            banks[_bankAddress].allowedToVote,
            banks[_bankAddress].regNumber
        );
    }

    function reportBank(address _bankAddress) public {
        require(
            banks[_bankAddress].ethAddress != address(0),
            "bank does not exist"
        );
        require(
            banks[msg.sender].ethAddress != address(0),
            "only a bank can call the function"
        );
        require(!hasVotedForBank[_bankAddress][msg.sender], "already reported");

        banks[_bankAddress].complaintsReported += 1;
        hasVotedForBank[_bankAddress][msg.sender] = true; //a bank can report another bank only once

        //if the number of complaints reported is greter than a third of total banks
        //then it can no longer vote
        if (banks[_bankAddress].complaintsReported > totalBanks / 3) {
            banks[_bankAddress].allowedToVote = false;
        }
    }
}
