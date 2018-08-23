#!/bin/bash

which hugeadm 2>&1 > /dev/null || { echo "no hugeadm found"; exit 1; }

# disable transparent hugepages
hugeadm --thp-never

# INVESTIGATE:
#
# LD_PRELOAD=libheapshrink.so heapshrink (2M: 64):	PASS
# LD_PRELOAD=libheapshrink.so heapshrink (1024M: 64):	PASS
# LD_PRELOAD=libhugetlbfs.so HUGETLB_MORECORE=yes heapshrink (2M: 64):	PASS
# LD_PRELOAD=libhugetlbfs.so HUGETLB_MORECORE=yes heapshrink (1024M: 64):	PASS
# LD_PRELOAD=libhugetlbfs.so libheapshrink.so HUGETLB_MORECORE=yes heapshrink (2M: 64):	PASS
# LD_PRELOAD=libhugetlbfs.so libheapshrink.so HUGETLB_MORECORE=yes heapshrink (1024M: 64):	PASS
# LD_PRELOAD=libheapshrink.so HUGETLB_MORECORE_SHRINK=yes HUGETLB_MORECORE=yes heapshrink (2M: 64):	PASS (inconclusive)
# LD_PRELOAD=libheapshrink.so HUGETLB_MORECORE_SHRINK=yes HUGETLB_MORECORE=yes heapshrink (1024M: 64):	PASS (inconclusive)
# LD_PRELOAD=libhugetlbfs.so libheapshrink.so HUGETLB_MORECORE_SHRINK=yes HUGETLB_MORECORE=yes heapshrink (2M: 64):	FAIL	Heap did not shrink
# LD_PRELOAD=libhugetlbfs.so libheapshrink.so HUGETLB_MORECORE_SHRINK=yes HUGETLB_MORECORE=yes heapshrink (1024M: 64):FAIL	Heap did not shrink
#
# FROM:
#
# do_test("heapshrink")
# do_test("heapshrink", LD_PRELOAD="libheapshrink.so")
# do_test("heapshrink", LD_PRELOAD="libhugetlbfs.so", HUGETLB_MORECORE="yes")
# do_test("heapshrink", LD_PRELOAD="libhugetlbfs.so libheapshrink.so", HUGETLB_MORECORE="yes")
# do_test("heapshrink", LD_PRELOAD="libheapshrink.so", HUGETLB_MORECORE="yes", HUGETLB_MORECORE_SHRINK="yes")
# do_test("heapshrink", LD_PRELOAD="libhugetlbfs.so libheapshrink.so", HUGETLB_MORECORE="yes", HUGETLB_MORECORE_SHRINK="yes")
#

export LD_LIBRARY_PATH=/opt/libhugetlbfs/tests/obj64

PROGRAM="/opt/libhugetlbfs/tests/obj64/heapshrink"

# LD_PRELOAD=libhugetlbfs.so = dynamic linker will load libhugetlbfs shared library libhugetlbfs.so
# LD_PRELOAD= = dynamic linker will load libhugetlbfs shared library libhugetlbfs.so

$PROGRAM
LD_PRELOAD="libheapshrink.so" $PROGRAM
LD_PRELOAD="libhugetlbfs.so" HUGETLB_MORECORE=yes $PROGRAM
LD_PRELOAD="libhugetlbfs.so libheapshrink.so" HUGETLB_MORECORE=yes $PROGRAM
LD_PRELOAD="libheapshrink.so" HUGETLB_MORECORE=yes HUGETLB_MORECORE_SHRINK=yes $PROGRAM
LD_PRELOAD="libhugetlbfs.so libheapshrink.so" HUGETLB_MORECORE_SHRINK=yes HUGETLB_MORECORE=yes $PROGRAM
