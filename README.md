#web-dialer-client-call-log
The call-log widget is for use with the web-dialer chrome extension.

After a call to a client or prospective client (not council members) the dialer will inject the call-log to the bottom of the page.

Users log the outcome of their calls to salesforce tasks. (See below for animated gif demo)

### Subject
Users enter in a short subject. Defaults to 'Call Log'.

### Contact (optional)
A list of **optional contacts** are displayed.  We find this list with a **reverse phone lookup**. In the event the person spoken to does not yet exist in our system, the user can leave these unchecked.

All contacts have a **hoverable info icon**.

### Outcome
A radio selection of outcomes that comes from salesforce.

### Description (optional)
A short description of what happened on the call

### CC Email (optional)
The list of contacts to be cc'd depending on the contact checked above.

## Source
See [src/call-log.litcoffee](src/call-log.litcoffee) for more technical details.

## DEPENDENCIES
The web-dialer-client-call-log needs deps in its sibling dir.

### ui-toolkit
```
git clone git@github.com:Custom-Elements/ui-toolkit.git; cd ui-toolkit
git checkout 131ed94
```
### semantic-ui
```
# from within web-dialer-client-call-log
cp -R ./node_modules/semantic-ui ../semantic-ui
```

## INSTALL
`npm install`

## RUN
`npm test`

Navigate to http://localhost:10000/demo.html
