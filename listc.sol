pragma solidity ^0.5.7;
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
        uint amount;
    }
    struct keyIdxValue { uint prevIdx; uint nextIdx; address src; uint value; }

    function init(list storage self) public returns (bool succ) {
        self.size = 0;
        self.head = 0;
        self.last = 0;
        self.seed = 0;
        self.amount = 0;
        return true;
    }

    function push(list storage self, address guy, uint val) public returns (uint x, uint s) {
        uint idx = self.seed++;

        self.data[idx].src = guy;
        self.data[idx].value = val;
        if (0 == self.size) {
            self.data[idx].prevIdx = uint(-1);
            self.data[idx].nextIdx = uint(-1);
            self.head = idx;
            self.last = idx;
        } else {
            self.data[self.last].nextIdx = idx;
            self.data[idx].prevIdx = self.last;
            self.data[idx].nextIdx = uint(-1);
            self.last = idx;
        }
        self.size++;
        self.amount += val;
        return (idx, self.size);
    }

    function pop(list storage self) public returns (address g, uint v) {
        require(self.size > 0, "Pop: fifo is empty.");

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
        self.amount -= val;
        return (guy, val);
    }
    
    function popsbynum(list storage self, uint num) public returns (uint l, address[] memory g, uint[] memory v) {
        require(self.amount > num && self.size > 0, "Popsbynum: pop exceed max nums.");
        address[] memory guys;
        uint[] memory vals;
        uint[] memory idxs;
        bool upd;
        uint i;
        uint newhead;

        (l, idxs, guys, vals, upd) = _peek3idxbynumF(self, num);

        if (0 != l) {
            newhead = idxs[l-1];
            if (true == upd) {
                self.data[newhead].prevIdx = uint(-1);
                self.head = newhead;
                for (i = 0; i < l-1; i++) {
                    delete self.data[idxs[i]];
                    self.size--;
                }
                uint idx = idxs[i];
                _updatebyidx(self, idx, self.data[idx].value-vals[i]);
            } else {
                newhead = self.data[newhead].nextIdx;
                if (newhead != uint(-1)) {
                    self.data[newhead].prevIdx = uint(-1);
                    self.head = newhead;
                }
                for (i = 0; i < l; i++) {
                    delete self.data[idxs[i]];
                    self.size--;
                }
            }
            self.amount -= num;
            return (l, guys, vals);
        } else {
            return (l, guys, vals);
        }
    }

    function _peek3idxbynumF(list storage self, uint num) public view returns (uint l, uint[] memory x, address[] memory g, uint[] memory v, bool u) {
        uint idx = self.head;
        address[] memory guys = new address[](self.size);
        uint[] memory vals = new uint[](self.size);
        uint[] memory idxs = new uint[](self.size);
        int res = int(num);
        uint i = 0;
        int val;

        //head
        guys[0] = self.data[idx].src;
        idxs[0] = idx;
        val = int(self.data[idx].value);
        if (res <= val) {
            vals[0] = uint(res);
            return (1, idxs, guys, vals, res==val?false:true);
        } else {
            res -= val;
            vals[i++] = uint(val);
        }

        while(res > 0 && i < self.size) {
            idx = getNextbyIdx(self, idx);
            if (idx != uint(-1)) {
                guys[i] = self.data[idx].src;
                idxs[i] = idx;
                val = int(self.data[idx].value);
                if (res <= val) {
                    vals[i] = uint(res);
                    return (i+1, idxs, guys, vals, res==val?false:true);
                } else {
                    res -= val;
                    vals[i++] = uint(val);
                }
            } else {
                return (0, idxs, guys, vals, false);
            }
        }
        return (0, idxs, guys, vals, false);
    }

    function withdraw1byidx(list storage self, uint idx) public returns (address g, uint v) {
        require(self.size > 0 && self.data[idx].src != address(0), "Withdraw1byidx: index is empty.");

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
        self.amount -= val;
        return (guy, val);
    }

    function withdraw1byaddr(list storage self, address guy) public returns (bool r, uint x, uint v) {
        require(self.size > 0, "Withdraw1byaddr: queue is empty.");
        bool ret;
        uint idx;
        uint val;

        (ret, idx, val) = _peek1idxbyaddrB(self, guy);
        if (true == ret) {
            withdraw1byidx(self, idx);
        }

        return (ret, idx, val);
    }

    function withdraw3bynum(list storage self, address guy, uint num) public returns (uint l, uint[] memory x, uint v) {
        require(self.size > 0 && self.amount > num, "Withdraw3bynum: queue is not enough.");
        uint idx;
        uint i;
        uint val;
        uint[] memory idxs;

        (l, idxs, val) = _peek3idxbyaddrAnumB(self, guy, num);
        if (0 != l) {
            if (val != 0) {
                for (i = 0; i < l-1; i++) {
                    idx = idxs[i];
                    withdraw1byidx(self, idx);
                }
                idx = idxs[i];
                self.amount -= val;
                _updatebyidx(self, idx, self.data[idx].value-val);
            } else {
                for (i = 0; i < l; i++) {
                    idx = idxs[i];
                    withdraw1byidx(self, idx);
                }
            }
            return (l, idxs, val);
        }

        return (l, idxs, val);
    }

    function _updatebyidx(list storage self, uint idx, uint val) public {
        uint value = self.data[idx].value;
        require(val < value, "Updatebyidx: target value is not correct.");
        self.data[idx].value = val;
    }

    function _peek3idxbyaddrAnumB(list storage self, address guy, uint num) public view returns (uint l, uint[] memory x, uint v) {
        require(self.size > 0, "Peek3idxbyaddrAnumB: queue is empty");

        uint idx = getLastIdx(self);
        uint[] memory idxs = new uint[](self.size);
        int res = int(num);
        uint i = 0;
        uint j = 0;
        int val;

        //last
        if (guy == self.data[idx].src) {
            idxs[0] = idx;
            val = int(self.data[idx].value);
            if (res < val) {
                return (1, idxs, uint(res));
            } else if (res == val) {
                return (1, idxs, uint(0));
            } else {
                res -= val;
                i++;
            }
            j++;
        }
        while(res > 0 && j++ < self.size) {
            idx = getPrevbyIdx(self, idx);
            if (guy == self.data[idx].src) {
                idxs[i++] = idx;
                val = int(self.data[idx].value);
                if (res < val) {
                    return (i, idxs, uint(res));
                } else if (res == val) {
                    return (i, idxs, uint(0));
                } else {
                    res -= val;
                }
            } else if (uint(-1) == idx) {
                return (0, idxs, uint(res));
            }
        }

        return (0, idxs, uint(res));
    }

    function _peek1idxbyaddrB(list storage self, address guy) public view returns (bool r, uint x, uint v) {
        require(self.size > 0, "Peek1idxbyaddrB: queue is empty");

        uint idx = getLastIdx(self);
        if (guy == self.data[idx].src) {
            return (true, idx, self.data[idx].value);
        } else if (uint(-1) == self.data[idx].prevIdx) { //size = 1
            return (false, uint(-1), 0);
        } else { //size > 1
            int loop = int(self.size);
            while (loop > 1) {
                idx = getPrevbyIdx(self, idx);
                if (guy == self.data[idx].src) {
                    return (true, idx, self.data[idx].value);
                }
                loop --;
            }
            return (false, uint(-1), 0);
        }
    }

    function getValueByIdx(list storage self, uint idx) public view returns (address g, uint v) {
      return (self.data[idx].src, self.data[idx].value);
    }

    function getStatusByIdx(list storage self, uint idx) public view returns (uint p, uint n, uint v, address g) {
      return (self.data[idx].prevIdx, self.data[idx].nextIdx, self.data[idx].value, self.data[idx].src);
    }

    function getPrevLastLByIdx(list storage self, uint idx) public view returns (uint p, uint n) {
      return (self.data[idx].prevIdx, self.data[idx].nextIdx);
    }

    function getHeadIdx(list storage self) public view returns (uint x) {
        return self.head;
    }

    function getLastIdx(list storage self) public view returns (uint x) {
        return self.last;
    }

    function getNextbyIdx(list storage self, uint idx) public view returns (uint x) {
        return self.data[idx].nextIdx;
    }

    function getPrevbyIdx(list storage self, uint idx) public view returns (uint x) {
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
    
    function cPushLoop(int loop) public {
        int i = 0;
        uint v = 50;
        while (i++ < loop) {
            vChain.push(data, msg.sender, v);
            v += 10;
        }
    }
    
    function cPeekbyNum(uint num) public view returns (uint l, uint[] memory x, address[] memory g, uint[] memory v, bool u) {
        return vChain._peek3idxbynumF(data, num);
    }

    function cPopbyNum(uint num) public returns (address[] memory g, uint[] memory v) {
        uint l;
        (l, g, v) = vChain.popsbynum(data, num);
        return (g, v);
    }

    function cPop() public returns (address g, uint v) {
        return vChain.pop(data);
    }
    
    function cPopLoop(int loop) public {
        int i = 0;
        while (i++ < loop) {
            vChain.pop(data);
        }
    }

    function cWithdraw(uint idx) public returns (address g, uint v) {
        return vChain.withdraw1byidx(data, idx);
    }

    function cWithdrawbyAddr(address guy) public returns (uint x, uint v) {
        bool r;
        (r, x, v) = vChain.withdraw1byaddr(data, guy);
        return (x, v);
    }

    function cWithdrawbyNum(address guy, uint num) public returns (uint[] memory x, uint v) {
        uint l;
        (l, x, v) = vChain.withdraw3bynum(data, guy, num);
        return (x, v);
    }

    function getValue(uint idx) public view returns (address g, uint v) {
      return vChain.getValueByIdx(data, idx);
    }

    function getStatus(uint idx) public view returns (uint p, uint n, uint v, address g) {
      return vChain.getStatusByIdx(data, idx);
    }

    function getPrevLast(uint idx) public view returns (uint p, uint n) {
      return vChain.getPrevLastLByIdx(data, idx);
    }

    function getHead() public view returns (uint x) {
        return vChain.getHeadIdx(data);
    }

    function getLast() public view returns (uint x) {
        return vChain.getLastIdx(data);
    }

    function getNext(uint idx) public view returns (uint x) {
        return vChain.getNextbyIdx(data, idx);
    }

    function getPrev(uint idx) public view returns (uint x) {
        return vChain.getPrevbyIdx(data, idx);
    }

    function getSize() public view returns (uint s) {
        return data.size;
    }
    
    function getAmount() public view returns (uint a) {
        return data.amount;
    }

    function getSeed() public view returns (uint s) {
        return data.seed;
    }
    
    function loopIdxForward() public view returns (uint[] memory xs) {
        require(data.size > 0, "LoopIdxForward: queue is empty.");
        uint[] memory idxs = new uint[](data.size);
        uint x = vChain.getHeadIdx(data);
        uint i = 0;
        idxs[i++] = x;
        x = vChain.getNextbyIdx(data, x);
        while (x != uint(-1)) {
            idxs[i++] = x;
            x = vChain.getNextbyIdx(data, x);
        }
        return (idxs);
    }

    function getBalanceAIdx(address guy) public view returns (uint[] memory xs, uint[] memory vs, uint b) {
        require(data.size > 0, "GetBalanceAIdx: queue is empty.");
        uint[] memory idxs = new uint[](data.size);
        uint[] memory vals = new uint[](data.size);
        uint x = vChain.getHeadIdx(data);
        uint i = 0;
        uint v;
        address g;
        b = 0;
        (g, v) = vChain.getValueByIdx(data, x);
        if (g == guy) {
            idxs[i] = x;
            vals[i++] = v;
            b += v;
        }
        x = vChain.getNextbyIdx(data, x);
        while (x != uint(-1)) {
            (g, v) = vChain.getValueByIdx(data, x);
            if (g == guy) {
                idxs[i] = x;
                vals[i++] = v;
                b += v;
            }
            x = vChain.getNextbyIdx(data, x);
        }
        return (idxs, vals, b);
    }
    
    function loopIdxBackward() public view returns (uint[] memory xs) {
        require(data.size > 0, "LoopIdxBackward: queue is empty.");
        uint[] memory idxs = new uint[](data.size);
        uint x = vChain.getLastIdx(data);
        uint i = 0;
        idxs[i++] = x;
        x = vChain.getPrevbyIdx(data, x);
        while (x != uint(-1)) {
            idxs[i++] = x;
            x = vChain.getPrevbyIdx(data, x);
        }
        return (idxs);
    }
    
    function loopValue() public view returns (uint[] memory vs) {
        require(data.size > 0, "LoopValue: queue is empty.");
        uint[] memory vals = new uint[](data.size);
        uint x = vChain.getHeadIdx(data);
        uint v;
        uint i = 0;
        address g;
        (g, v) = vChain.getValueByIdx(data, x);
        vals[i++] = v;
        x = vChain.getNextbyIdx(data, x);
        while (x != uint(-1)) {
            (g, v) = vChain.getValueByIdx(data, x);
            vals[i++] = v;
            x = vChain.getNextbyIdx(data, x);
        }
        return (vals);
    }
    
    function loopAddress() public view returns (address[] memory gs) {
        require(data.size > 0, "LoopAddress: queue is empty.");
        address[] memory guys = new address[](data.size);
        uint x = vChain.getHeadIdx(data);
        uint v;
        address g;
        uint i = 0;
        (g, v) = vChain.getValueByIdx(data, x);
        guys[i++] = g;
        x = vChain.getNextbyIdx(data, x);
        while (x != uint(-1)) {
            (g, v) = vChain.getValueByIdx(data, x);
            guys[i++] = g;
            x = vChain.getNextbyIdx(data, x);
        }
        return (guys);
    }

    function loopForward() public {
        require(data.size > 0, "LoopForward: queue is empty.");
        uint x = vChain.getHeadIdx(data);
        int loop = int(data.size);

        while (loop > 0) {
            (uint p, uint n, uint v, address g) = vChain.getStatusByIdx(data, x);
            emit LogKeyValue(int(x), int(p), int(n), v, g);
            x = vChain.getNextbyIdx(data, x);
            if (uint(-1) == x)
                break;
            loop --;
        }
    }

    function loopBackward() public {
        require(data.size > 0, "LoopBackward: queue is empty.");
        uint x = vChain.getLastIdx(data);
        int loop = int(data.size);

        while (loop > 0) {
            (uint p, uint n, uint v, address g) = vChain.getStatusByIdx(data, x);
            emit LogKeyValue(int(x), int(p), int(n), v, g);
            x = vChain.getPrevbyIdx(data, x);
            if (uint(-1) == x)
                break;
            loop --;
        }
    }
}