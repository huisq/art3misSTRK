pub fn convert1(word: felt252, len: usize) -> ByteArray {
    let mut output = "";
    output.append_word(word, len);
    output
}

pub fn convert2(word1: felt252, word2: felt252, len2: usize) -> ByteArray {
    let mut output = "";
    output.append_word(word1, 31);
    output.append_word(word2, len2);
    output
}

pub fn convert3(word1: felt252, word2: felt252, word3: felt252, len3: usize) -> ByteArray {
    let mut output = "";
    output.append_word(word1, 31);
    output.append_word(word2, 31);
    output.append_word(word3, len3);
    output
}
