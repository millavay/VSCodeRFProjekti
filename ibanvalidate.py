def IsIbanCorrect(iban):
    # Remove spaces and convert to uppercase
    cleaned = iban.replace(' ', '').upper()
    
    #tarkistetaan onko pituus oikea, suomen IBAN on 18 merkkiä pitkä
    if len(cleaned) != 18:
        return False
    
    #return True
    
    #siirretään ekat neljä merkkiä loppuun, osa IBAN tarkistusta
    rearranged = cleaned[4:] + cleaned[:4]
    #korvataan kirjaimet numeroilla
    numeric = ''.join([str(ord(c) - 55) if c.isalpha() else c for c in rearranged])
    #tarkistetaan jakojäännös 97:llä, IBAN tarkistus vaatii, että jakojäännös on 1
    return int(numeric) % 97 == 1