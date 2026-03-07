def IsIbanCorrect(iban):
    cleaned = iban.replace(' ', '').upper()
    
    if len(cleaned) != 18:
        return False
    
    #return True
    
    
    rearranged = cleaned[4:] + cleaned[:4]
    numeric = ''.join([str(ord(c) - 55) if c.isalpha() else c for c in rearranged])
    
    return int(numeric) % 97 == 1