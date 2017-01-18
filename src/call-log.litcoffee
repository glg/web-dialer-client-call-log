#call-log
The call-log gets injected by the web-dialer chrome extension after calls.
Users log the outcome of their calls to salesforce tasks.

    moment = require 'moment'

    _ = require 'underscore' # because lodash has weird
    # loading issues with browserify + requirejs!

    # The following is necessary to undo saleforce's `prototype.js`.
    # `prototype.js` is the precursor to jQuery (for any youngins).
    # It wasn't cool.
    delete Array.prototype.toJSON

    Polymer 'call-log',

##Events

Attributes and Change Handlers

        contactsJSONChanged: () ->
            @contacts = JSON.parse @contactsJSON
            @contacts = _.filter @contacts, (contact) ->
                contact.logInd
            @reset()

        sfdcProjectIdChanged: ()->
            if @sfdcProjectId is "undefined" # edge case when no attributes altogether.
                @projectIds = []
            else # handles the empty attribute case with compact
                @projectIds = _.compact(@sfdcProjectId.split(','))

        # TODO: Some placeholder for how this could work:
        # For now leave this off by not honoring this as a public attribute in call-log.html
        vegaProjectIdChanged: () ->
            alert 'Not yet fully implemented'
            unless @projectIds
                @projectIds = _.compact(@vegaProjectId.split(','))

        projectIdsChanged: () ->
            @projects = []
            if (@projectIds).length > 0
                @projectIdsCSV = encodeURIComponent @projectIds.join(',')
            @reset()

        ajaxProjectsResponseChanged: () ->
            @projects = @ajaxProjectsResponse
            for project in @projects
                project = _.extend project,
                    type: @projectType
            @projectsLoaded = true

        # Custom checkbox behavior to ensure only one selected.
        # Unfortunately this is not a radio button per se,
        # because you should be able to unselect in the case we don't currently
        # have the contact listed.
        contactSelectedChanged: (oldVal, newVal) ->
            for contactCheckbox in @$.callLogContainer.querySelectorAll "input[name='contact']"
                contactCheckbox.checked = false unless contactCheckbox.value == newVal?.salesforceId

            @$.ajaxContactInfo.url = if newVal then "#{@sfApiServer}/api/contact/sf/#{newVal.salesforceId}" else ""

        # TODO: Rename the callTypes to outcome to normalize and make clear.
        callTypeSelectedChanged: (oldVal, newVal) ->
            if (newVal == null)
                @resetCallTypeSelected()

        sfApiServerChanged: () ->
            that = @
            @$.ajaxDescribe.addEventListener 'core-response', (e) ->
                if (!@response)
                    that.errors.push "Can't conect to salesforce api server."
                else
                    that.selectionsLoaded = true
                    that.selections = _.find(@response.fields, {name: 'call_outcome__c'}).picklistValues

            @$.ajaxContactInfo.addEventListener 'core-response', (e) ->

                if (!@response)
                    that.errors.push "Can't conect to salesforce api server."
                    return

                response = @response[0]
                if (response)
                    # below handles CRAZY salesforce structure.
                    ccListToDisplay = {}
                    contactFields = [
                        'Owner',
                        'Secondary_Sales__r',
                        'Rm_Coverage_Primary__r',
                        'Rm_Coverage_AFA__r',
                        'Rm_Coverage_CGS__r',
                        'Rm_Coverage_EI__r',
                        'Rm_Coverage_FBS__r',
                        'Rm_Coverage_HC__r',
                        'Rm_Coverage_LERA__r',
                        'Rm_Coverage_RE__r',
                        'Rm_Coverage_TMT__r'
                    ]

                    cleanRole = (role) ->
                        role
                            .replace 'Rm_Coverage_', ''
                            .replace '__r', ''

                    contactFields.forEach (e, i, a) ->
                        if (e of response)
                            current = response[e]
                            if not (current.Id of ccListToDisplay)
                                ccListToDisplay[current.Id] = { id: current.Id, email: current.Email, name: current.Name }
                            ccListToDisplay[current.Id].roles = _.union ccListToDisplay[current.Id].roles, [cleanRole(e)]

                    that.ccListToDisplay.push value for key, value of ccListToDisplay

            @$.ajaxSubmit.addEventListener 'core-response', (e) ->
                that.close()

##Methods

        reset: () ->
            @clearErrors()
            @resetCCList()
            @description = ""
            @contactSelected = null  # Should I do an array of props?
            @resetProjectsSelected()
            @callTypeSelected = null # This is a pretty crazy code smell...
            @subject = "Call Log"
            @$.subject.focus()

        resetProjectsSelected: () -> # TODO: This is really singular for now (1 project)
            for projectCheckbox in @$.callLogContainer.querySelectorAll "input[name='project']"
                projectCheckbox.checked = false

        resetCallTypeSelected: () ->
            for callTypeRadio in @$.callLogContainer.querySelectorAll "input[name='callType']"
                callTypeRadio.checked = false

        clearErrors: () ->
            fields = @$.callLogContainer.getElementsByClassName 'field'
            [].forEach.call fields, (field, index, array) ->
                field.classList.remove 'error'
            @errors = []

        resetCCList: () ->
            @ccListToDisplay = []

##Event Handlers

        close: (event, detail, sender) ->
            @reset()
            @fire 'call-log-cancel', {}

        selectCallType: (event, detail, sender) ->
            @callTypeSelected = sender.value

        selectContact: (event, detail, sender) ->
            contact = event.target.templateInstance.model.c
            @resetCCList() # Do not follow temptation to move this below to avoid flicker of change state.
            if (!sender.checked)
                @contactSelected = null
            else
                @contactSelected = contact

        selectAssociatedProject: (event, detail, sender) ->
            project = event.target.templateInstance.model.project
            # @resetCCList() # TODO: WHEN projects add to cc.. feature is built.
            # TODO: Add more people to cc list!
            # maybe, what I can do is change the approach to instead of resetting..
            # fire off a rebuild of the cc list either from here in order to
            # ensure reading all of the proper cc's (contact and projects)

        ajaxProjectsError: (event, response) ->
            @projectIds = []

        submit: (event, detail, sender) ->
            getSelectedInputs = (name) => # (Helper)
                return [].slice.call(@$.callLogContainer.querySelectorAll "input[name='#{name}']")
                    .filter (input) ->
                        input.checked

            submitTime = moment()

            ccListSelected = getSelectedInputs 'cc'
            sfdcProjectsSelected = getSelectedInputs 'project'

            # grab just the emails! I stored them in the dom attr (heh)
            ccListSelected = (cc.getAttribute('email') for cc in ccListSelected)

            sfdcProjectsSelected = (proj.getAttribute('id') for proj in sfdcProjectsSelected)

            # make sure prop names match salesforce/make sure prop names match salesforce
            results =
                Subject: @subject
                activity_type__c: 'Call'
                Status: if @contactSelected then 'Completed' else 'In Progress'
                ActivityDate: submitTime.toISOString()
                OwnerId: @owner
                WhoId: @contactSelected?.salesforceId # works fine if null.
                call_outcome__c: @callTypeSelected
                Description: @description
                cc_list__c: ccListSelected.join ','
                number_dialed__c: @numberDialed
                Origin__c: @origin
                origin_url__c: @originUrl
                EventRecOrigin__c: @origin == "HappeningsEventRecommender"

            @clearErrors()

            # The descriptions field used to be required as well. see: 0086e6796abc49382d459912b7cf67968071356d

            if (results.call_outcome__c == undefined || results.call_outcome__c == null)
                @$.callTypes.classList.add 'error'
                @errors.push 'Please select a description from the list'

            # Silent ignore (just truncate don't throw an error!):
            results.cc_list__c = results.cc_list__c.substring(0, 255)

            if (!@errors.length)
                # 1. Save Task
                if !sfdcProjectsSelected.length # no projects selected
                    ajaxSubmit = @$.ajaxSubmit
                    ajaxSubmit.body = JSON.stringify results
                    ajaxSubmit.go()
                else # projects selected
                    for project in sfdcProjectsSelected
                        results.WhatId = project

                        ajaxSubmit = @$.ajaxSubmit
                        ajaxSubmit.body = JSON.stringify results
                        ajaxSubmit.go()

                # 2. Send CC emails
                if (not _.isEmpty ccListSelected)
                    ajaxCC = @$.ajaxCC
                    ajaxCC.body = JSON.stringify
                        From: @ownerEmail
                        To: ({ Address: emailAddress} for emailAddress in ccListSelected)
                        Subject: results.Subject
                        spokeTo: @contactSelected.name
                        client: @contactSelected.clientName
                        date: submitTime.format('LLLL')
                        outcome: results.call_outcome__c
                        description: results.Description
                        # TODO: Add these to the email template first!
                        # numberDialed: @numberDialed
                        # TODO: (as a link) add the following:
                        # relatedProjectId:
                        # relatedProjectName:
                    ajaxCC.go()

##Polymer Lifecycle

        created: () ->
            @selections = []
            @contacts = []
            @errors = []

        ready: () ->
            # If the outer page didn't supply the projectIds and projectType
            # we should try and look it up! (multiple might be returned!)
            if !@projectIds or !@projectType
                # TODO Reverse lookup projects if no id!
                @projects = []

Need to trap keypresses for github's hotkeys for example.  This is of particular interest for extensions.

            for input in @$.callLogContainer.querySelectorAll "textarea, input[type='text']"
                for event in ['keydown', 'keyup', 'keypress']
                    input.addEventListener event, (e) ->
                        e.stopPropagation()
                        return true
