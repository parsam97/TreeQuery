# TreeQuery

TreeQuery allows you to build SOQL queries, using 'selectors', powered by `Where-Object` and Powershell. Use TreeQuery when you don't know what query you want, don't know how to write it properly, or just don't feel like writing tens of hundreds of queries (all with the correct fields, references, child relationships, etc).

Let's take an example.

## Usage

Always first import the module into your environment before calling the class methods.

```Powershell
using module .\SOQLBuilder.psm1
```

Using TreeQuery and this documentation assumes you have a basic understanding of Powershell and some of its methods like [Where-Object](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/where-object?view=powershell-7.4) and [Select-Object](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/select-object?view=powershell-7.4). Brush up on [Powershell regular expressions](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_regular_expressions?view=powershell-7.4) too.

### Basic

If you want a query on the Account object, with only custom fields:

```Powershell
[SOQLBuilder]::new().
    AddSObjects({ $_ -eq 'Account' }).
    AddFields({ $_.custom }).
    Export()
```

This should yield:

```soql
SELECT Id, MyCustomField__c, Foo__c FROM Account
```

Let's say you work with CPQ, and you want queries for every CPQ object, with all their fields:

```Powershell
[SOQLBuilder]::new().
    AddSObjects({ $_ -match 'SBQQ__.*__c\b' }).
    AddFields().
    Export()
```

This should yield a `.soql` file for every query/object that matches the pattern. Just beware, that command will take a while because TreeQuery makes a describe call for every object in order to get its metadata.

### Parent Queries

Let's say you you want to retrieve custom Account fields within your Contact query, which also targets only custom fields:

```Powershell
[SOQLBuilder]::new().
    AddSObjects({ $_ -eq 'Contact' }).
    AddFields({ $_.custom }).
    AddParentQueries([SOQLBuilder]::new().
        AddSObjects({ $_ -eq 'Account' }).
        AddFields({ $_.custom })
    ).
    Export()
```

This should yield:

```soql
SELECT Id, MyCustomField__c, Account.Id, Account.MyCustomField__c
FROM Contact
```

Let's say you want SOQL queries for every CPQ object that may or may not be the parent to an Account record:

```Powershell
[SOQLBuilder]::new().
    AddSObjects({ $_ -match 'SBQQ__.*__c\b' }).
    AddFields().
    AddParentQueries([SOQLBuilder]::new().
        AddSObjects({ $_ -eq 'Account' }).
        AddFields()
    ).
    Export()
```

Note: If there was no parent Account for an object, the SOQL file is still created. It only will not have any parent Account field references.

### Inner Queries

This is the fun one. Usually we don't remember off the top of our head what the relationship name of a particular relationship is between two objects. Sometimes, you may not even know if the relationship exists or not. This often happens when you are trying to debug an issue and cannot figure out where the problem lies.

Let's start simple. Let's say you want to retrieve Contacts of some Accounts. 

```Powershell
[SOQLBuilder]::new().
    AddSObjects({ $_ -eq 'Account' }).
    AddFields().
    AddChildQueries([SOQLBuilder]::new().
        AddSObjects({ $_ -eq 'Contact' }).
        AddFields()
    ).
    Export()
```

A bit more complex. Let's say you want a single SOQL query on Product2 and all its children that belong to objects start with SBQQ__Product:

```Powershell
[SOQLBuilder]::new().
    AddSObjects({ $_ -eq 'Product2' }).
    AddChildQueries([SOQLBuilder]::new().
        AddSObjects({ $_ -match 'SBQQ__Product.*__c\b'})
    ).
    Export()
```

This should yield:

```soql
SELECT Id,
	(SELECT Id
	FROM SBQQ__ProductActions__r),	(SELECT Id
	FROM SBQQ__Features__r),	(SELECT Id
	FROM SBQQ__Options__r),		(SELECT Id
		FROM SBQQ__OptionalFor__r)
FROM Product2
```

The example above finds the relationship name for you, while you simply specify the object name. If you prefer to add inner queries through the object describe result's `childRelationships` value, you can provide the selector for that instead. The equivalent of the example above with the second way would be:

```Powershell
[SOQLBuilder]::new().
    AddSObjects({ $_ -eq 'Product2' }).
    AddChildQueries({ $_.childSObject -match 'SBQQ__Product.*__c\b' }, [SOQLBuilder]::new().
        AddSObjects({ $_ -match 'SBQQ__Product.*__c\b' })
    ).
    Export()
```

You might think specifying the match is redundant. But TreeQuery will first resolve the inner `[SOQLBuilder]::new().AddSObjects({ $_ -match 'SBQQ__Product.*__c\b' })`. This will result in whatever objects that are found. Then it will ensure every one of the resulting objects are indeed defined as being a child relationship to the parent `Product2` object. After that, it will apply your selector `{ $_.childSObject -match 'SBQQ__Product.*__c\b' }`.

### Selector Options

Run the following in your terminal to see what available properties you have to filter by in your field selectors.

```Powershell
$(sf sobject describe -s Account --json | ConvertFrom-Json).result.fields[0]
```

We are simply taking the first field describe result of the Account object as an example. For me, this yields the following:

```Powershell
PS C:\Users\parsa\src\TreeQuery> $(sf sobject describe -s Account --json | ConvertFrom-Json).result.fields[0]

aggregatable                 : True
aiPredictionField            : False
autoNumber                   : False
byteLength                   : 18
calculated                   : False
calculatedFormula            : 
cascadeDelete                : False
caseSensitive                : False
compoundFieldName            : 
controllerName               : 
createable                   : False
custom                       : False
defaultValue                 : 
defaultValueFormula          : 
defaultedOnCreate            : True
dependentPicklist            : False
deprecatedAndHidden          : False
digits                       : 0
displayLocationInDecimal     : False
encrypted                    : False
externalId                   : False
extraTypeInfo                : 
filterable                   : True
filteredLookupInfo           : 
formulaTreatNullNumberAsZero : False
groupable                    : True
highScaleNumber              : False
htmlFormatted                : False
idLookup                     : True
inlineHelpText               : 
label                        : Account ID
length                       : 18
mask                         : 
maskType                     : 
name                         : Id
nameField                    : False
namePointing                 : False
nillable                     : False
permissionable               : False
picklistValues               : {}
polymorphicForeignKey        : False
precision                    : 0
queryByDistance              : False
referenceTargetField         : 
referenceTo                  : {}
relationshipName             : 
relationshipOrder            : 
restrictedDelete             : False
restrictedPicklist           : False
scale                        : 0
searchPrefilterable          : False
soapType                     : tns:ID
sortable                     : True
type                         : id
unique                       : False
updateable                   : False
writeRequiresMasterRead      : False
```

Any and all of these properties are available to you in your selectors, thanks to Salesforce describe calls + Powershell.

Run the following in your terminal to see what available properties you have to filter by in your `childRelationships` selectors.

```Powershell
$(sf sobject describe -s Account --json | ConvertFrom-Json).result.childRelationships[0]
```

```Powershell
PS C:\Users\parsa\src\TreeQuery> $(sf sobject describe -s Account --json | ConvertFrom-Json).result.childRelationships[95]

cascadeDelete       : False
childSObject        : OrderItem
deprecatedAndHidden : False
field               : SBQQ__ShippingAccount__c
junctionIdListNames : {}
junctionReferenceTo : {}
relationshipName    : SBQQ__ShippingAccountOrderProducts__r
restrictedDelete    : False
```

How can one remember that the relationship name in this case is `SBQQ__ShippingAccountOrderProducts__r`? No one remembers, they check. But if you need to, for example, get all Accounts and any children of CPQ objects and the _Name_ fields for those, you can do the following:

```Powershell
[SOQLBuilder]::new().
    AddSObjects({ $_ -eq 'Account' }).
    AddChildQueries([SOQLBuilder]::new().
        AddSObjects({ $_ -match 'SBQQ__.*__c\b' }).
        AddFields({ $_.nameField })
    ).
    Export()
```

This should yield:

```soql
SELECT Id,
	(SELECT Id,Name
	FROM SBQQ__R00N70000001olI5EAI__r),	(SELECT Id,Name
	FROM SBQQ__Discount_Schedules__r),	(SELECT Id,Name
	FROM SBQQ__PriceSchedules__r),	(SELECT Id,Name
	FROM SBQQ__QuoteLineGroups__r),	(SELECT Id,Name
	FROM Quote_Lines__r),	(SELECT Id,Name
	FROM SBQQ__Quotes__r),		(SELECT Id,Name
		FROM SBQQ__DistributorQuotes__r),			(SELECT Id,Name
			FROM SBQQ__PartnerQuotes__r),	(SELECT Id,Name
	FROM Subscriptions__r),		(SELECT Id,Name
		FROM SBQQ__Subscriptions__r),	(SELECT Id,Name
	FROM SBQQ__Tax_Exemption_Certificates__r),	(SELECT Id,Name
	FROM SBQQ__WebQuotes__r)
FROM Account
```

> What the hell is that `SBQQ__R00N70000001olI5EAI__r`? 😄

### All SOQLBuilder methods

- [SOQLBuilder] MakeVerbose()
- [SOQLBuilder] NameJob([String]$JobName)
- [SOQLBuilder] AddSObjects([ScriptBlock]$Selector)
- [SOQLBuilder] AddFields()
- [SOQLBuilder] AddFieldString([String]$Field)
- [SOQLBuilder] AddFields([ScriptBlock]$Selector)
- [SOQLBuilder] AddWhere([String]$WhereClause)
- [SOQLBuilder] AddOrderBy([ScriptBlock]$Selector)
- [SOQLBuilder] AddOrderBy([ScriptBlock]$Selector, [String]$Direction)
- [SOQLBuilder] AddLimit([Int]$Limit)
- [SOQLBuilder] AddOffset([Int]$Offset)
- [SOQLBuilder] AddChildQueries([ScriptBlock]$RelationFieldSelector, [SOQLBuilder]$ChildBuilder)
- [SOQLBuilder] AddChildQueries([SOQLBuilder]$ChildBuilder)
- [SOQLBuilder] AddParentQueries([ScriptBlock]$RelationFieldSelector, [SOQLBuilder]$ParentBuilder)
- [SOQLBuilder] AddParentQueries([SOQLBuilder]$ParentBuilder)
- [SOQLBuilder] GetQueryTexts()
- [SOQLBuilder] Export()
- [SOQLBuilder] Export([Boolean]$WithPlan)
- [SOQLBuilder] Execute() // uses `sf data export beta tree`
