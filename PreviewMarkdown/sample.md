# H1 #

Some body text.

## H2 ##

*Some body text in italic.*

### H3 ###

**Some body text in bold**

#### H4 ####

**Some body text in bold** and then not bold **and then bold again**.

```
code
```

##### H5 #####

1. A list
1. A list
1. A list

###### H6 ######

- A bullet list
- A bullet list
- A bullet list
    * A sub bullet list
    * A sub bullet list

#### H4 Again

* Point One
* Point Two

## H2 Again ##

Some `preformatted text` in `this line`.

| A | B | C |
| :-- | :-: | --: |
| 1 | 2 | 3 |

### Code ###

    func showError(_ errString: String) {

        // Relay an error message to its various outlets

        NSLog("BUFFOON " + errString)
        self.errorReportField.stringValue = errString
        self.errorReportField.isHidden = false
    }