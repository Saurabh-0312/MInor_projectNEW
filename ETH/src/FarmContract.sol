// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract FarmingSystem {
    enum CropStatus { Registered, ContractVerified, InspectorVerified, Rejected, Listed, Sold }
    enum CultivationMethod { Traditional, Organic, Hydroponic, Greenhouse, Other }
    enum CertificationStatus { None, Organic, NonGMO, FairTrade, Multiple }
    enum QualityGrade { A, B, C, Premium, Standard }

    struct Crop {
        uint256 cropId;
        address farmer;
        string cropType;
        uint256 quantity;
        uint256 harvestDate;
        string farmLocation;
        CertificationStatus certificationStatus;
        CultivationMethod cultivationMethod;
        string irrigationSource;
        string fertilizerInfo;
        string pesticideUsage;
        string soilHealthMetrics;
        uint256 shelfLifeDays;
        string storageConditions;
        uint256 pricePerUnit;
        uint256 carbonFootprint;
        QualityGrade qualityGrade;
        CropStatus status;
        string rejectionReason;
        address inspector;
        uint256 registrationTime;
        uint256 verificationTime;
    }

    struct ParameterThreshold {
        uint256 minQuantity;
        uint256 maxShelfLife;
        uint256 maxCarbonFootprint;
    }

    mapping(uint256 => Crop) public crops;
    mapping(string => ParameterThreshold) public cropThresholds;
    uint256 public cropCounter = 0;
    
    address public owner;
    mapping(address => bool) public authorizedInspectors;
    
    event CropRegistered(uint256 cropId, address farmer, string cropType);
    event CropVerifiedByContract(uint256 cropId);
    event CropVerifiedByInspector(uint256 cropId, address inspector);
    event CropRejected(uint256 cropId, string reason);
    event CropListed(uint256 cropId, uint256 price);
    event CropSold(uint256 cropId, address buyer);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only contract owner can call this function");
        _;
    }
    
    modifier onlyInspector() {
        require(authorizedInspectors[msg.sender], "Only authorized inspectors can call this function");
        _;
    }
    
    modifier onlyFarmer(uint256 _cropId) {
        require(crops[_cropId].farmer == msg.sender, "Only the crop's farmer can call this function");
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    function addInspector(address _inspector) external onlyOwner {
        authorizedInspectors[_inspector] = true;
    }
    
    function removeInspector(address _inspector) external onlyOwner {
        authorizedInspectors[_inspector] = false;
    }
    
    function setCropThreshold(
        string memory _cropType,
        uint256 _minQuantity,
        uint256 _maxShelfLife,
        uint256 _maxCarbonFootprint
    ) external onlyOwner {
        cropThresholds[_cropType] = ParameterThreshold(
            _minQuantity,
            _maxShelfLife,
            _maxCarbonFootprint
        );
    }
    
    function registerCrop(
        string memory _cropType,
        uint256 _quantity,
        uint256 _harvestDate,
        string memory _farmLocation,
        CertificationStatus _certificationStatus,
        CultivationMethod _cultivationMethod,
        string memory _irrigationSource,
        string memory _fertilizerInfo,
        string memory _pesticideUsage,
        string memory _soilHealthMetrics,
        uint256 _shelfLifeDays,
        string memory _storageConditions,
        uint256 _pricePerUnit,
        uint256 _carbonFootprint,
        QualityGrade _qualityGrade
    ) external returns (uint256) {
        cropCounter++;
        
        crops[cropCounter] = Crop({
            cropId: cropCounter,
            farmer: msg.sender,
            cropType: _cropType,
            quantity: _quantity,
            harvestDate: _harvestDate,
            farmLocation: _farmLocation,
            certificationStatus: _certificationStatus,
            cultivationMethod: _cultivationMethod,
            irrigationSource: _irrigationSource,
            fertilizerInfo: _fertilizerInfo,
            pesticideUsage: _pesticideUsage,
            soilHealthMetrics: _soilHealthMetrics,
            shelfLifeDays: _shelfLifeDays,
            storageConditions: _storageConditions,
            pricePerUnit: _pricePerUnit,
            carbonFootprint: _carbonFootprint,
            qualityGrade: _qualityGrade,
            status: CropStatus.Registered,
            rejectionReason: "",
            inspector: address(0),
            registrationTime: block.timestamp,
            verificationTime: 0
        });
        
        emit CropRegistered(cropCounter, msg.sender, _cropType);
        
        // Automatically verify by contract
        _verifyByContract(cropCounter);
        
        return cropCounter;
    }
    
    function _verifyByContract(uint256 _cropId) internal {
        Crop storage crop = crops[_cropId];
        ParameterThreshold memory threshold = cropThresholds[crop.cropType];
        
        // If no specific thresholds are set for this crop type, it passes automatic verification
        if (threshold.minQuantity == 0) {
            crop.status = CropStatus.ContractVerified;
            emit CropVerifiedByContract(_cropId);
            return;
        }
        
        // Validate parameters against thresholds
        bool isValid = true;
        string memory reason = "";
        
        if (crop.quantity < threshold.minQuantity) {
            isValid = false;
            reason = "Quantity below minimum threshold";
        } else if (crop.shelfLifeDays > threshold.maxShelfLife) {
            isValid = false;
            reason = "Shelf life exceeds maximum threshold";
        } else if (crop.carbonFootprint > threshold.maxCarbonFootprint) {
            isValid = false;
            reason = "Carbon footprint exceeds maximum threshold";
        }
        
        if (isValid) {
            crop.status = CropStatus.ContractVerified;
            emit CropVerifiedByContract(_cropId);
        } else {
            crop.status = CropStatus.Rejected;
            crop.rejectionReason = reason;
            emit CropRejected(_cropId, reason);
        }
    }
    
    function verifyByInspector(uint256 _cropId, bool _approved, string memory _rejectionReason) external onlyInspector {
        Crop storage crop = crops[_cropId];
        require(crop.status == CropStatus.ContractVerified, "Crop not ready for inspector verification");
        
        if (_approved) {
            crop.status = CropStatus.InspectorVerified;
            crop.inspector = msg.sender;
            crop.verificationTime = block.timestamp;
            emit CropVerifiedByInspector(_cropId, msg.sender);
        } else {
            crop.status = CropStatus.Rejected;
            crop.rejectionReason = _rejectionReason;
            emit CropRejected(_cropId, _rejectionReason);
        }
    }
    
    function listCrop(uint256 _cropId) external onlyFarmer(_cropId) {
        Crop storage crop = crops[_cropId];
        require(crop.status == CropStatus.InspectorVerified, "Crop not verified by inspector");
        
        crop.status = CropStatus.Listed;
        emit CropListed(_cropId, crop.pricePerUnit);
    }
    
    function buyCrop(uint256 _cropId) external payable {
        Crop storage crop = crops[_cropId];
        require(crop.status == CropStatus.Listed, "Crop not available for purchase");
        require(msg.value >= crop.pricePerUnit * crop.quantity, "Insufficient payment");
        
        crop.status = CropStatus.Sold;
        
        // Transfer payment to farmer
        payable(crop.farmer).transfer(msg.value);
        
        emit CropSold(_cropId, msg.sender);
    }
    
    function updateCropParameters(
        uint256 _cropId,
        uint256 _quantity,
        uint256 _harvestDate,
        string memory _farmLocation,
        CertificationStatus _certificationStatus,
        CultivationMethod _cultivationMethod,
        string memory _irrigationSource,
        string memory _fertilizerInfo,
        string memory _pesticideUsage,
        string memory _soilHealthMetrics,
        uint256 _shelfLifeDays,
        string memory _storageConditions,
        uint256 _pricePerUnit,
        uint256 _carbonFootprint,
        QualityGrade _qualityGrade
    ) external onlyFarmer(_cropId) {
        Crop storage crop = crops[_cropId];
        require(crop.status == CropStatus.Registered || crop.status == CropStatus.Rejected, "Cannot update parameters at this stage");
        
        crop.quantity = _quantity;
        crop.harvestDate = _harvestDate;
        crop.farmLocation = _farmLocation;
        crop.certificationStatus = _certificationStatus;
        crop.cultivationMethod = _cultivationMethod;
        crop.irrigationSource = _irrigationSource;
        crop.fertilizerInfo = _fertilizerInfo;
        crop.pesticideUsage = _pesticideUsage;
        crop.soilHealthMetrics = _soilHealthMetrics;
        crop.shelfLifeDays = _shelfLifeDays;
        crop.storageConditions = _storageConditions;
        crop.pricePerUnit = _pricePerUnit;
        crop.carbonFootprint = _carbonFootprint;
        crop.qualityGrade = _qualityGrade;
        crop.status = CropStatus.Registered;
        crop.rejectionReason = "";
        
        // Re-verify the crop
        _verifyByContract(_cropId);
    }
    
    function getCropDetails(uint256 _cropId) external view returns (
        address farmer,
        string memory cropType,
        uint256 quantity,
        uint256 harvestDate,
        CertificationStatus certificationStatus,
        CultivationMethod cultivationMethod,
        QualityGrade qualityGrade,
        CropStatus status,
        uint256 pricePerUnit
    ) {
        Crop storage crop = crops[_cropId];
        return (
            crop.farmer,
            crop.cropType,
            crop.quantity,
            crop.harvestDate,
            crop.certificationStatus,
            crop.cultivationMethod,
            crop.qualityGrade,
            crop.status,
            crop.pricePerUnit
        );
    }
    
    function getCropExtendedDetails(uint256 _cropId) external view returns (
        string memory farmLocation,
        string memory irrigationSource,
        string memory fertilizerInfo,
        string memory pesticideUsage,
        string memory soilHealthMetrics,
        uint256 shelfLifeDays,
        string memory storageConditions,
        uint256 carbonFootprint,
        string memory rejectionReason,
        address inspector,
        uint256 registrationTime,
        uint256 verificationTime
    ) {
        Crop storage crop = crops[_cropId];
        return (
            crop.farmLocation,
            crop.irrigationSource,
            crop.fertilizerInfo,
            crop.pesticideUsage,
            crop.soilHealthMetrics,
            crop.shelfLifeDays,
            crop.storageConditions,
            crop.carbonFootprint,
            crop.rejectionReason,
            crop.inspector,
            crop.registrationTime,
            crop.verificationTime
        );
    }
}