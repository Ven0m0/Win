#Requires -Version 5.1

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
    # Dot-source merged script; main block is gated so no side effects
    . "$PSScriptRoot/../Scripts/Optimize-Steam.ps1"
}

Describe "Steam-Config.ps1 — VDF parser" {
    Context "parsevdf" {
        It "Parses a minimal valid VDF string" {
            $vdf = '"root"' + "`r`n{`r`n}`r`n"
            $tree = parsevdf $vdf
            $tree.name | Should -Be 'root'
            $tree.node.entries.Count | Should -Be 0
        }

        It "Parses a key-value pair inside the root block" {
            $vdf = '"root"' + "`r`n{`r`n`t`"key`"`t`t`"value`"`r`n}`r`n"
            $tree = parsevdf $vdf
            $tree.node.entries.Count | Should -Be 1
            $tree.node.entries[0].name | Should -Be 'key'
            $tree.node.entries[0].value | Should -Be 'value'
        }

        It "Parses a nested block" {
            $vdf = '"root"' + "`r`n{`r`n`t`"section`"`r`n`t{`r`n`t}`r`n}`r`n"
            $tree = parsevdf $vdf
            $tree.node.entries[0].kind | Should -Be 'block'
            $tree.node.entries[0].name | Should -Be 'section'
        }

        It "Throws on missing root key" {
            { parsevdf '{}' } | Should -Throw
        }

        It "Throws on missing root block" {
            { parsevdf '"root"' } | Should -Throw
        }
    }

    Context "writevdf" {
        It "Produces parseable output from a roundtrip" {
            $vdf = '"root"' + "`r`n{`r`n`t`"key`"`t`t`"value`"`r`n}`r`n"
            $tree = parsevdf $vdf
            $output = writevdf $tree
            $tree2 = parsevdf $output
            $tree2.name | Should -Be 'root'
            $tree2.node.entries[0].value | Should -Be 'value'
        }

        It "Escapes backslashes in written output" {
            $vdf = '"root"' + "`r`n{`r`n`t`"path`"`t`t`"C:\\Steam`"`r`n}`r`n"
            $tree = parsevdf $vdf
            $output = writevdf $tree
            $output | Should -Match '\\\\'
        }
    }

    Context "findentry" {
        It "Returns the index of an existing entry" {
            $vdf = '"root"' + "`r`n{`r`n`t`"alpha`"`t`t`"1`"`r`n`t`"beta`"`t`t`"2`"`r`n}`r`n"
            $tree = parsevdf $vdf
            findentry $tree.node 'beta' | Should -Be 1
        }

        It "Returns -1 when the entry does not exist" {
            $vdf = '"root"' + "`r`n{`r`n`t`"alpha`"`t`t`"1`"`r`n}`r`n"
            $tree = parsevdf $vdf
            findentry $tree.node 'missing' | Should -Be -1
        }

        It "Performs case-sensitive lookup" {
            $vdf = '"root"' + "`r`n{`r`n`t`"Key`"`t`t`"1`"`r`n}`r`n"
            $tree = parsevdf $vdf
            findentry $tree.node 'key' | Should -Be -1
            findentry $tree.node 'Key' | Should -Be 0
        }
    }

    Context "setvalue" {
        It "Adds a new key-value entry when key does not exist" {
            $vdf = '"root"' + "`r`n{`r`n}`r`n"
            $tree = parsevdf $vdf
            setvalue $tree.node 'newkey' 'newval'
            $tree.node.entries.Count | Should -Be 1
            $tree.node.entries[0].value | Should -Be 'newval'
        }

        It "Updates an existing value in place" {
            $vdf = '"root"' + "`r`n{`r`n`t`"key`"`t`t`"old`"`r`n}`r`n"
            $tree = parsevdf $vdf
            setvalue $tree.node 'key' 'new'
            $tree.node.entries.Count | Should -Be 1
            $tree.node.entries[0].value | Should -Be 'new'
        }

        It "Throws when trying to set a value on a block entry" {
            $vdf = '"root"' + "`r`n{`r`n`t`"section`"`r`n`t{`r`n`t}`r`n}`r`n"
            $tree = parsevdf $vdf
            { setvalue $tree.node 'section' 'val' } | Should -Throw
        }
    }

    Context "ensureblock" {
        It "Creates a new child block when it does not exist" {
            $vdf = '"root"' + "`r`n{`r`n}`r`n"
            $tree = parsevdf $vdf
            $child = ensureblock $tree.node 'section'
            $child | Should -Not -BeNullOrEmpty
            $tree.node.entries.Count | Should -Be 1
            $tree.node.entries[0].kind | Should -Be 'block'
        }

        It "Returns the existing block node when it already exists" {
            $vdf = '"root"' + "`r`n{`r`n`t`"section`"`r`n`t{`r`n`t`"k`"`t`t`"v`"`r`n`t}`r`n}`r`n"
            $tree = parsevdf $vdf
            $child = ensureblock $tree.node 'section'
            $child.entries.Count | Should -Be 1
        }

        It "Throws when the named entry is a value, not a block" {
            $vdf = '"root"' + "`r`n{`r`n`t`"flat`"`t`t`"val`"`r`n}`r`n"
            $tree = parsevdf $vdf
            { ensureblock $tree.node 'flat' } | Should -Throw
        }
    }

    Context "settings application roundtrip" {
        It "Applies all $settings keys to an empty VDF tree without error" {
            $vdf = '"UserLocalConfigStore"' + "`r`n{`r`n}`r`n"
            $tree = parsevdf $vdf

            $root = $tree.node
            foreach ($scope in $settings.Keys) {
                $node = if ($scope -eq 'root') { $root } else { ensureblock $root $scope }
                foreach ($name in $settings[$scope].Keys) {
                    { setvalue $node $name $settings[$scope][$name] } | Should -Not -Throw
                }
            }
        }

        It "Roundtrips the modified tree without data loss" {
            $vdf = '"UserLocalConfigStore"' + "`r`n{`r`n}`r`n"
            $tree = parsevdf $vdf
            $root = $tree.node
            setvalue $root 'LibraryLowBandwidthMode' '1'

            $out = writevdf $tree
            $tree2 = parsevdf $out
            $i = findentry $tree2.node 'LibraryLowBandwidthMode'
            $tree2.node.entries[$i].value | Should -Be '1'
        }
    }
}
