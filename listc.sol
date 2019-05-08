pragma solidity ^0.5.1;
/// @dev Models a uint -> uint mapping where it is possible to iterate over all keys.
library vChain
{
    struct list
    {
        mapping(uint => keyIdxValue) data;
        uint size;
        uint head;
        uint last;
        uint seed;
    }
    struct keyIdxValue { uint prevIdx; uint nextIdx; address src; uint value; }
    struct keyflag { bool inUse; }
    
    function init(list storage self) public returns (bool succ) {
        self.size = 0;
        self.head = 0;
        self.last = 0;
        self.seed = 0;
        return true;
    }

    function push(list storage self, address guy, uint val) public returns (uint x, uint s) {
        uint idx = self.seed++;

        self.data[idx].src   = guy;
        self.data[idx].value = val;
        if (self.size == 0) {
            self.data[idx].prevIdx  = uint(-1);
            self.data[idx].nextIdx  = uint(-1);
            self.head = idx;
            self.last = idx;
        } else {
            self.data[self.last].nextIdx = idx;
            self.data[idx].prevIdx = self.last;
            self.data[idx].nextIdx = uint(-1);
            self.last = idx;
        }
        self.size++;
        return (idx, self.size);
    }

    function pop(list storage self) public returns (address g, uint v) {
        require(self.size > 0, "pop: fifo is empty.");

        uint ihead = self.head;
        uint nextIdx = self.data[ihead].nextIdx;
        
        address guy = self.data[ihead].src;
        uint    val = self.data[ihead].value;
        delete self.data[ihead];
        if (nextIdx != uint(-1)) {
            self.data[nextIdx].prevIdx = uint(-1);
            self.head = nextIdx;
        }
        self.size--;
        return (guy, val);
    }
    
    function withdraw(list storage self, uint idx) public returns (address g, uint v) {
        require(self.size > 0 && self.data[idx].src != address(0), "withdraw: index is empty.");
        
        address guy = self.data[idx].src;
        uint    val = self.data[idx].value;
        if (idx == self.head) {
            return pop(self);
        } else if (idx == self.last) {
            uint prevIdx = self.data[idx].prevIdx;
            if (prevIdx != uint(-1)) {
                self.data[prevIdx].nextIdx = uint(-1);
                self.last = prevIdx;
            }
        } else {
            uint prevIdx = self.data[idx].prevIdx;
            uint netxIdx = self.data[idx].nextIdx;
            self.data[prevIdx].nextIdx = netxIdx;
            self.data[netxIdx].prevIdx = prevIdx;
        }
        delete self.data[idx];
        self.size--;
        return (guy, val);
    }

    function getValueByIdx(list storage self, uint idx) view public returns (address g, uint v) {
      return (self.data[idx].src, self.data[idx].value);
    }
    
    function getStatusByIdx(list storage self, uint idx) view public returns (uint p, uint n, uint v, address g) {
      return (self.data[idx].prevIdx, self.data[idx].nextIdx, self.data[idx].value, self.data[idx].src);
    }
    
    function getPrevLastLByIdx(list storage self, uint idx) view public returns (uint p, uint n) {
      return (self.data[idx].prevIdx, self.data[idx].nextIdx);
    }
    
    function getHeadIdx(list storage self) view public returns (uint x) {
        return self.head;
    }
    
    function getLastIdx(list storage self) view public returns (uint x) {
        return self.last;
    }
    
    function getNextbyIdx(list storage self, uint idx) view public returns (uint x) {
        return self.data[idx].nextIdx;
    }
    
    function getPrevbyIdx(list storage self, uint idx) view public returns (uint x) {
        return self.data[idx].prevIdx;
    }
}

contract Main
{
    vChain.list public data;
    
    event LogKeyValue(int next, int prev, int idx, uint val, address guy);

    function cInit() public returns (bool sc) {
        return vChain.init(data);
    }
    
    function cPush(uint val) public returns (uint x, uint s) {
        return vChain.push(data, msg.sender, val);
    }

    function cPop() public returns (address g, uint v) {
        return vChain.pop(data);
    }

    function cWithdraw(uint idx) public returns (address g, uint v) {
        return vChain.withdraw(data, idx);
    }

    function getValue(uint idx) view public returns (address g, uint v) {
      return vChain.getValueByIdx(data, idx);
    }
    
    function getStatus(uint idx) view public returns (uint p, uint n, uint v, address g) {
      return vChain.getStatusByIdx(data, idx);
    }
    
    function getPrevLast(uint idx) view public returns (uint p, uint n) {
      return vChain.getPrevLastLByIdx(data, idx);
    }
    
    function getHead() view public returns (uint x) {
        return vChain.getHeadIdx(data);
    }
    
    function getLast() view public returns (uint x) {
        return vChain.getLastIdx(data);
    }
    
    function getNext(uint idx) view public returns (uint x) {
        return vChain.getNextbyIdx(data, idx);
    }
    
    function getPrev(uint idx) view public returns (uint x) {
        return vChain.getPrevbyIdx(data, idx);
    }
    
    function getSize() view public returns (uint s) {
        return data.size;
    }
    
    function getSeed() view public returns (uint s) {
        return data.seed;
    }
    
    function loopForward() public {
        uint x = vChain.getHeadIdx(data);
        int loop = int(data.size);

        while (loop > 0) {
            (uint p, uint n, uint v, address g) = vChain.getStatusByIdx(data, x);
            emit LogKeyValue(int(x), int(p), int(n), v, g);
            x = vChain.getNextbyIdx(data, x);
            if (x == uint(-1))
                break;
            loop --;
        }
    }
    
    function loopBackward() public {
        uint x = vChain.getLastIdx(data);
        int loop = int(data.size);

        while (loop > 0) {
            (uint p, uint n, uint v, address g) = vChain.getStatusByIdx(data, x);
            emit LogKeyValue(int(x), int(p), int(n), v, g);
            x = vChain.getPrevbyIdx(data, x);
            if (x == uint(-1))
                break;
            loop --;
        }
    }
}