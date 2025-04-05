// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract SupplyChain {
    enum CropStatus {
        Pending,
        FirstApproved,
        Approved,
        Rejected,
        Sold
    }

    struct Crop {
        uint256 id;
        address farmer;
        string name;
        string pesticidesUsed;
        string fertilizersUsed;
        string location;
        string ipfsHash; // IPFS hash for documents/images
        CropStatus status;
        uint256 price;
        address buyer;
    }

    struct User {
        address userAddress;
        string role; // "Farmer", "Inspector", "Customer"
        uint256 reputation;
    }

    address public admin;
    uint256 public cropCount;

    mapping(address => User) public users;
    mapping(uint256 => Crop) public crops;

    mapping(uint256 => mapping(address => bool)) public inspectorApproved;
    mapping(uint256 => uint256) public approvalCount;

    event CropRegistered(uint256 indexed cropId, address farmer);
    event CropReviewed(uint256 indexed cropId, address inspector, CropStatus status);
    event CropSold(uint256 indexed cropId, address buyer);

    modifier onlyRole(string memory _role) {
        require(keccak256(bytes(users[msg.sender].role)) == keccak256(bytes(_role)), "Unauthorized");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function registerUser(string memory _role) public {
        require(bytes(users[msg.sender].role).length == 0, "Already registered");
        require(
            keccak256(bytes(_role)) == keccak256("Farmer") || keccak256(bytes(_role)) == keccak256("Inspector")
                || keccak256(bytes(_role)) == keccak256("Customer"),
            "Invalid role"
        );
        users[msg.sender] = User(msg.sender, _role, 0);
    }

    function registerCrop(
        string memory _name,
        string memory _pesticidesUsed,
        string memory _fertilizersUsed,
        string memory _location,
        string memory _ipfsHash,
        uint256 _price
    ) public onlyRole("Farmer") {
        cropCount++;
        crops[cropCount] = Crop({
            id: cropCount,
            farmer: msg.sender,
            name: _name,
            pesticidesUsed: _pesticidesUsed,
            fertilizersUsed: _fertilizersUsed,
            location: _location,
            ipfsHash: _ipfsHash,
            status: CropStatus.Pending,
            price: _price,
            buyer: address(0)
        });
        emit CropRegistered(cropCount, msg.sender);
    }

    function reviewCrop(uint256 _cropId, bool _approved) public onlyRole("Inspector") {
        Crop storage crop = crops[_cropId];
        require(crop.status == CropStatus.Pending || crop.status == CropStatus.FirstApproved, "Already finalized");
        require(!inspectorApproved[_cropId][msg.sender], "Already reviewed");

        inspectorApproved[_cropId][msg.sender] = true;

        if (_approved) {
            approvalCount[_cropId]++;
            if (approvalCount[_cropId] == 1) {
                crop.status = CropStatus.FirstApproved;
            } else if (approvalCount[_cropId] == 2) {
                crop.status = CropStatus.Approved;
            }
        } else {
            crop.status = CropStatus.Rejected;
        }

        emit CropReviewed(_cropId, msg.sender, crop.status);
    }

    function buyCrop(uint256 _cropId) public payable onlyRole("Customer") {
        Crop storage crop = crops[_cropId];
        require(crop.status == CropStatus.Approved, "Not for sale");
        require(msg.value == crop.price, "Incorrect payment");
        require(crop.buyer == address(0), "Already sold");

        crop.buyer = msg.sender;
        crop.status = CropStatus.Sold;

        payable(crop.farmer).transfer(msg.value);

        emit CropSold(_cropId, msg.sender);
    }

    // Optional: Get crop details
    function getCrop(uint256 _cropId) public view returns (Crop memory) {
        return crops[_cropId];
    }
}
