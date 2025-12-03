// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract PharmaSupplyChain {
    
    // Enums for product status and roles
    enum Role { None, Manufacturer, Distributor, Retailer }
    enum ProductStatus { Created, Packed, Shipped, InTransit, Delivered, Violated }
    
    // Structs
    struct User {
        address userAddress;
        Role role;
        string publicKey; // ECC public key
        string name;
        bool isRegistered;
    }
    
    struct Product {
        string productId;
        string name;
        address manufacturer;
        uint256 manufactureDate;
        uint256 expiryDate;
        int256 minTemp;
        int256 maxTemp;
        int256 minHumidity;
        int256 maxHumidity;
        ProductStatus status;
        address currentOwner;
        string batchNumber;
        string offChainDataHash; // Hash of MongoDB document
        bool exists;
    }
    
    struct TemperatureLog {
        int256 temperature;
        int256 humidity;
        uint256 timestamp;
        address loggedBy;
        string location;
    }
    
    struct Transaction {
        address from;
        address to;
        uint256 timestamp;
        ProductStatus status;
        string remarks;
    }
    
    address public owner;
    uint256 public productCount;
    
    // Mappings
    mapping(address => User) public users;
    mapping(string => Product) public products;
    mapping(string => TemperatureLog[]) public temperatureLogs;
    mapping(string => Transaction[]) public productTransactions;
    mapping(address => string[]) public userProducts; // Products owned by user
    
    // Events
    event UserRegistered(address indexed userAddress, Role role, string name);
    event ProductCreated(string indexed productId, string name, address indexed manufacturer);
    event ProductStatusUpdated(string indexed productId, ProductStatus status, address indexed updatedBy);
    event TemperatureLogged(string indexed productId, int256 temperature, int256 humidity, address indexed loggedBy);
    event ProductTransferred(string indexed productId, address indexed from, address indexed to);
    event TemperatureViolation(string indexed productId, int256 temperature, int256 humidity);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this");
        _;
    }
    modifier onlyRegistered() {
        require(users[msg.sender].isRegistered, "User not registered");
        _;
    }
    modifier onlyRole(Role _role) {
        require(users[msg.sender].role == _role, "Unauthorized role");
        _;
    }
    modifier productExists(string memory _productId) {
        require(products[_productId].exists, "Product does not exist");
        _;
    }
    modifier onlyProductOwner(string memory _productId) {
        require(products[_productId].currentOwner == msg.sender, "Not product owner");
        _;
    }
    constructor() {
        owner = msg.sender;
    }
    
    // User Management
    function registerUser(
        address _userAddress,
        Role _role,
        string memory _publicKey,
        string memory _name
    ) public onlyOwner {
        require(!users[_userAddress].isRegistered, "User already registered");
        require(_role != Role.None, "Invalid role");
        
        users[_userAddress] = User({
            userAddress: _userAddress,
            role: _role,
            publicKey: _publicKey,
            name: _name,
            isRegistered: true
        });
        
        emit UserRegistered(_userAddress, _role, _name);
    }
    
    // Product Creation (Only Manufacturer)
    function createProduct(
        string memory _productId,
        string memory _name,
        uint256 _expiryDate,
        int256 _minTemp,
        int256 _maxTemp,
        int256 _minHumidity,
        int256 _maxHumidity,
        string memory _batchNumber,
        string memory _offChainDataHash
    ) public onlyRegistered onlyRole(Role.Manufacturer) {
        require(!products[_productId].exists, "Product already exists");
        require(_expiryDate > block.timestamp, "Invalid expiry date");
        
        products[_productId] = Product({
            productId: _productId,
            name: _name,
            manufacturer: msg.sender,
            manufactureDate: block.timestamp,
            expiryDate: _expiryDate,
            minTemp: _minTemp,
            maxTemp: _maxTemp,
            minHumidity: _minHumidity,
            maxHumidity: _maxHumidity,
            status: ProductStatus.Created,
            currentOwner: msg.sender,
            batchNumber: _batchNumber,
            offChainDataHash: _offChainDataHash,
            exists: true
        });
        
        userProducts[msg.sender].push(_productId);
        productCount++;
        
        // Log initial transaction
        productTransactions[_productId].push(Transaction({
            from: address(0),
            to: msg.sender,
            timestamp: block.timestamp,
            status: ProductStatus.Created,
            remarks: "Product created by manufacturer"
        }));
        
        emit ProductCreated(_productId, _name, msg.sender);
    }
    
    // Log Temperature and Humidity
    function logTemperature(
        string memory _productId,
        int256 _temperature,
        int256 _humidity,
        string memory _location
    ) public onlyRegistered productExists(_productId) onlyProductOwner(_productId) {
        Product storage product = products[_productId];
        
        // Check if temperature/humidity is within range
        bool violation = false;
        if (_temperature < product.minTemp || _temperature > product.maxTemp) {
            violation = true;
        }
        if (_humidity < product.minHumidity || _humidity > product.maxHumidity) {
            violation = true;
        }
        
        // Log the temperature
        temperatureLogs[_productId].push(TemperatureLog({
            temperature: _temperature,
            humidity: _humidity,
            timestamp: block.timestamp,
            loggedBy: msg.sender,
            location: _location
        }));
        
        emit TemperatureLogged(_productId, _temperature, _humidity, msg.sender);
        
        // If violation, update status and halt shipment
        if (violation) {
            product.status = ProductStatus.Violated;
            emit TemperatureViolation(_productId, _temperature, _humidity);
            emit ProductStatusUpdated(_productId, ProductStatus.Violated, msg.sender);
        }
    }
    
    // Update Product Status
    function updateProductStatus(
        string memory _productId,
        ProductStatus _newStatus
    ) public onlyRegistered productExists(_productId) onlyProductOwner(_productId) {
        Product storage product = products[_productId];
        require(product.status != ProductStatus.Violated, "Cannot update violated product");
        
        product.status = _newStatus;
        
        productTransactions[_productId].push(Transaction({
            from: msg.sender,
            to: msg.sender,
            timestamp: block.timestamp,
            status: _newStatus,
            remarks: "Status updated"
        }));
        
        emit ProductStatusUpdated(_productId, _newStatus, msg.sender);
    }
    
    // Transfer Product Ownership
    function transferProduct(
        string memory _productId,
        address _to
    ) public onlyRegistered productExists(_productId) onlyProductOwner(_productId) {
        require(users[_to].isRegistered, "Recipient not registered");
        Product storage product = products[_productId];
        require(product.status != ProductStatus.Violated, "Cannot transfer violated product");
        
        address previousOwner = product.currentOwner;
        product.currentOwner = _to;
        
        // Update ownership records
        userProducts[_to].push(_productId);
        
        // Log transaction
        productTransactions[_productId].push(Transaction({
            from: previousOwner,
            to: _to,
            timestamp: block.timestamp,
            status: product.status,
            remarks: "Product transferred"
        }));
        
        emit ProductTransferred(_productId, previousOwner, _to);
    }
    
    // View Functions
    function getProduct(string memory _productId) public view returns (Product memory) {
        require(products[_productId].exists, "Product does not exist");
        return products[_productId];
    }
    
    function getTemperatureLogs(string memory _productId) public view returns (TemperatureLog[] memory) {
        return temperatureLogs[_productId];
    }
    
    function getProductTransactions(string memory _productId) public view returns (Transaction[] memory) {
        return productTransactions[_productId];
    }
    
    function getUserProducts(address _user) public view returns (string[] memory) {
        return userProducts[_user];
    }
    
    function getUser(address _userAddress) public view returns (User memory) {
        return users[_userAddress];
    }
    
    function verifyProductAuthenticity(string memory _productId) public view returns (bool, string memory) {
        if (!products[_productId].exists) {
            return (false, "Product does not exist");
        }
        
        Product memory product = products[_productId];
        
        if (product.status == ProductStatus.Violated) {
            return (false, "Product violated temperature/humidity conditions");
        }
        
        if (block.timestamp > product.expiryDate) {
            return (false, "Product expired");
        }
        
        return (true, "Product is authentic and safe");
    }
}
