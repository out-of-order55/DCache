# 简介
DCache组织结构为2路组相联,2*4K,一个cacheline大小为16byte,替代算法用的伪lru算法,组织结构为->data域:256*32的sram8块,TAGV域:256*21的sram两块,LRU:256*1的regfile一块    
