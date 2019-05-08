pragma solidity ^0.5.1;
/// @dev Models a uint -> uint mapping where it is possible to iterate over all keys.
library vChain
{
    struct list
    {
        mapping(uint => keyIdxValue) data;
        keyflag[] keyflags;
        uint size;
        uint head;
        uint last;
    }
    struct keyIdxValue { uint prevIdx; uint nextIdx; address src; uint value; }
    struct keyflag { bool inUse; }
    
    function init(list storage self) public returns (bool succ) {
        self.size = 0;
        self.head = 0;
        self.last = 0;
        return true;
    }
    
    function getFreeToUse(list storage self) view public returns (bool h, uint p) {
        uint len  = self.keyflags.length;
        uint size = self.size;
        bool has = false;
        uint pos = uint(-1);
        
        require(len >= size);
        if (size == len) 
            return (false, uint(-1));
        else {
            uint i = 0;
            while (i < len) {
                if (self.keyflags[i].inUse == false) {
                    has = true;
                    pos = i;
                    break;
                }
                i++;
            }
            return (has, pos);
        }
    }

    function push(list storage self, address guy, uint val) public returns (uint x, uint s) {
        bool has;
        uint idx;
        (has, idx) = getFreeToUse(self);
        if (has == false)
            idx = self.keyflags.length++;

        self.data[idx].src   = guy;
        self.data[idx].value = val;
        self.keyflags[idx].inUse = true;
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
        self.keyflags[ihead].inUse = false;
        delete self.data[ihead];
        if (nextIdx != uint(-1)) {
            self.data[nextIdx].prevIdx = uint(-1);
            self.head = nextIdx;
        }
        self.size--;
        return (guy, val);
    }
    
    function withdraw(list storage self, uint idx) public returns (address g, uint v) {
        require(self.keyflags[idx].inUse == true, "withdraw: index is empty.");
        
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
        self.keyflags[idx].inUse = false;
        delete self.data[idx];
        self.size--;
        return (guy, val);
    }
    
    event KeyFlags(uint pos, bool inUse);
    function printkeyflags(list storage self) public returns (uint l) {
        for (uint i=0; i<self.keyflags.length; i++) {
            emit KeyFlags(i, self.keyflags[i].inUse);
        }
        return self.keyflags.length;
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
    
    event LogKeyValue(int idx, int prev, int next, uint val, address guy);

    function cInit() public returns (bool sc) {
        return vChain.init(data);
    }
    
    function cPush(uint val) public returns (uint x, uint s) {
        return vChain.push(data, msg.sender, val);
    }

    function cPop() public returns (address g, uint v) {
        return vChain.pop(data);
    }
    
    function getFreeIdx() view public returns (bool h, uint p) {
        return vChain.getFreeToUse(data);
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
    
    function getPrev(uint idx) view public returns (uint x) {
        return vChain.getPrevbyIdx(data, idx);
    }
    
    function getNext(uint idx) view public returns (uint x) {
        return vChain.getNextbyIdx(data, idx);
    }
    
    function getSize() view public returns (uint s) {
        return data.size;
    }
    
    function getLength() view public returns (uint l) {
        return data.keyflags.length;
    }
    
    function printKeyFlags() public {
        vChain.printkeyflags(data);
    }
    
    function loopForward() public {
        uint x = vChain.getHeadIdx(data);
        int loop = int(data.size);

        while (loop > 0) {
            (uint p, uint n, uint v, address g) = vChain.getStatusByIdx(data, x);
            emit LogKeyValue(int(p), int(x), int(n), v, g);
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
            emit LogKeyValue(int(p), int(x), int(n), v, g);
            x = vChain.getPrevbyIdx(data, x);
            if (x == uint(-1))
                break;
            loop --;
        }
    }
}