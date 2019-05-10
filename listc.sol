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
        return (guy, val);
    }

    function popsbynum(list storage self, uint num) public returns (bool r, address[] memory g, uint[] memory v) {
        require(self.size > 0, "Popsbynum: queue is empty");

        uint idx = getHeadIdx(self);
        address[] memory guys;
        uint[] memory vals;
        int res = int(num);
        uint i = 0;
        int val;

        //head
        guys[0] = self.data[idx].src;
        val = int(self.data[idx].value);
        if (res < val) {
            vals[0] = uint(res);
            _updatebyidx(self, idx, uint(val-res));
            return (true, guys, vals);
        } else if (res == val) {
            vals[0] = uint(res);
            uint x = getNextbyIdx(self, idx);
            if (x != uint(-1)) {
                self.data[x].prevIdx = uint(-1);
                self.head = x;
            }
            self.size--;
            return (true, guys, vals);
        } else {
            res -= val;
            vals[i++] = uint(val);
            self.size--;
        }

        while(res > 0 && i < self.size) {
            idx = getNextbyIdx(self, idx);
            if (idx != uint(-1)) {
                guys[i] = self.data[idx].src;
                val = int(self.data[idx].value);
                if (res < val) {
                    vals[i] = uint(res);
                    _updatebyidx(self, idx, uint(val-res));
                    self.head = idx;
                    return (true, guys, vals);
                } else if (res == val) {
                    vals[i] = uint(res);
                    uint x = getNextbyIdx(self, idx);
                    if (x != uint(-1)) {
                        self.data[x].prevIdx = uint(-1);
                        self.head = x;
                    }
                    self.size--;
                    return (true, guys, vals);
                } else {
                    res -= val;
                    vals[i++] = uint(val);
                    self.size--;
                }
            } else {
                return (false, guys, vals);
            }
        }
        return (false, guys, vals);
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
        return (guy, val);
    }

    function withdraw1byaddr(list storage self, address guy) public returns (bool r, uint x, uint v) {
        bool ret;
        uint idx;
        uint val;

        (ret, idx, val) = _peek1idxbyaddrB(self, guy);
        if (true == ret) {
            withdraw1byidx(self, idx);
        }

        return (ret, idx, val);
    }

    function withdraw3bynum(list storage self, address guy, uint num) public returns (bool r, uint[] memory x, uint v) {
        bool ret;
        uint idx;
        uint i;
        uint val;
        uint[] memory idxs;

        (ret, idxs, val) = _peek3idxbyaddrAnumB(self, guy, num);
        if (true == ret) {
            if (val != 0) {
                for (i = 0; i < idxs.length-1; i++) {
                    idx = idxs[i];
                    withdraw1byidx(self, idx);
                }
                idx = idxs[i];
                _updatebyidx(self, idx, self.data[idx].value-val);
            } else {
                for (i = 0; i < idxs.length; i++) {
                    idx = idxs[i];
                    withdraw1byidx(self, idx);
                }
            }
            return (true, idxs, val);
        }

        return (false, idxs, val);
    }

    function _updatebyidx(list storage self, uint idx, uint val) public returns (bool r, uint v) {
        uint value = self.data[idx].value;
        require(val < value, "Updatebyidx: target value is not correct.");
        self.data[idx].value = val;
        return (true, val);
    }

    function _peek3idxbyaddrAnumB(list storage self, address guy, uint num) public view returns (bool r, uint[] memory x, uint v) {
        require(self.size > 0, "Peek3idxbyaddrAnumB: queue is empty");

        uint idx = getLastIdx(self);
        uint[] memory idxs;
        int res = int(num);
        uint i = 0;
        uint j = 0;
        int val;

        //last
        if (guy == self.data[idx].src) {
            idxs[0] = idx;
            val = int(self.data[idx].value);
            if (res < val) {
                return (true, idxs, uint(res));
            } else if (res == val) {
                return (true, idxs, uint(0));
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
                    return (true, idxs, uint(res));
                } else if (res == val) {
                    return (true, idxs, uint(0));
                } else {
                    res -= val;
                }
            } else if (uint(-1) == idx) {
                return (false, idxs, uint(res));
            }
        }

        return (false, idxs, uint(res));
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

    function cPopbyNum(uint num) public returns (address[] memory g, uint[] memory v) {
        bool r;
        (r, g, v) = vChain.popsbynum(data, num);
        return (g, v);
    }

    function cPop() public returns (address g, uint v) {
        return vChain.pop(data);
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
        bool r;
        (r, x, v) = vChain.withdraw3bynum(data, guy, num);
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

    function getSeed() public view returns (uint s) {
        return data.seed;
    }

    function loopForward() public {
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