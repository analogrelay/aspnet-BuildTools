using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Runtime.Loader;
using Microsoft.Extensions.CommandLineUtils;

namespace aspnet_build
{
    public class Program
    {
        private static readonly string Version = typeof(Program).GetTypeInfo().Assembly.GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion;
        private static readonly string MSBuildAppTypeName = "Microsoft.Build.CommandLine.MSBuildApp";

        public static int Main(string[] args)
        {
            var app = new CommandLineApplication(throwOnUnexpectedArg: true);
            app.Name = "aspnet-build";
            app.FullName = "ASP.NET Core Build Tool";
            app.VersionOption("-v|--version", Version);
            app.HelpOption("-h|-?|--help");

            app.Command("msbuild", RegisterMSBuildCommand, throwOnUnexpectedArg: false);

            var repoArgument = app.Argument("REPO", "Path to the repo to build");
            var targetOption = app.Option("-t|--target <TARGET>", "MSBuild target(s) to run", CommandOptionType.MultipleValue);
            var propOption = app.Option("-p|--property <PROPERTY=VALUE>", "MSBuild properties to set for this build", CommandOptionType.MultipleValue);
            var msbuildArgOption = app.Option("-a|--msbuild-arg <ARGUMENT>", "Additional MSBuild arguments to pass verbatim", CommandOptionType.MultipleValue);

            app.OnExecute(() =>
            {
                var repo = string.IsNullOrEmpty(repoArgument.Value) ? Directory.GetCurrentDirectory() : repoArgument.Value;

                var success = true;
                var props = propOption.Values.Select(s =>
                {
                    var splat = s.Split('=');
                    if(splat.Length != 2)
                    {
                        Console.Error.WriteLine($"Invalid property specification: '{s}'. Expected [NAME]=[VALUE]");
                        success = false;
                        return null;
                    }
                    return Tuple.Create(splat[0], splat[1]);
                }).Where(t => t != null).ToDictionary(t => t.Item1, t => t.Item2);

                if(!success)
                {
                    return 1;
                }

                var makefile = GetMakefileForRepo(repo);

                var msbuildArgs = new List<string>();
                msbuildArgs.Add(makefile);
                msbuildArgs.AddRange(targetOption.Values.Select(t => $"/t:{t}"));
                msbuildArgs.AddRange(props.Select(p => $"/p:{p.Key}=\"{p.Value}\""));
                msbuildArgs.AddRange(msbuildArgOption.Values);

                return ExecuteMSBuild(msbuildArgs.ToArray());
            });

            return app.Execute(args);
        }

        private static void RegisterMSBuildCommand(CommandLineApplication cmd)
        {
            cmd.Description = "Run MSBuild directly with the arguments provided";

            cmd.OnExecute(() => ExecuteMSBuild(cmd.RemainingArguments.ToArray()));
        }

        private static string GetMakefileForRepo(string repoDir)
        {
            var candidateMakefile = Path.Combine(repoDir, "makefile.proj");
            if (File.Exists(candidateMakefile))
            {
                return candidateMakefile;
            }
            else
            {
                return Path.Combine(AppContext.BaseDirectory, "msbuild", "DefaultMakefile.proj");
            }
        }

        private static int ExecuteMSBuild(string[] msbuildArgs)
        {
            Console.WriteLine("> msbuild " + string.Join(" ", msbuildArgs));
            var msbuildPath = Path.Combine(AppContext.BaseDirectory, "runtimes", "any", "native", "MSBuild.exe");
            if (!File.Exists(msbuildPath))
            {
                Console.Error.WriteLine($"Unable to locate MSBuild in: {msbuildPath}");
                Console.Error.WriteLine("aspnet-build must be published with 'dotnet publish' to execute correctly");
                return 1000;
            }
            Environment.SetEnvironmentVariable("MSBUILD_EXE_PATH", msbuildPath);

            // Load MSBuild exe
            var msbuildAsm = AssemblyLoadContext.Default.LoadFromAssemblyPath(msbuildPath);

            // Locate the app
            var msbuildAppType = msbuildAsm.GetType(MSBuildAppTypeName);
            if (msbuildAppType == null)
            {
                Console.Error.WriteLine($"Failed to locate {MSBuildAppTypeName} type in MSBuild.exe!");
                return 1001;
            }

            // Find the execute method
            var msbuildExecuteMethod = msbuildAppType.GetTypeInfo().GetMethod("Execute", new[] { typeof(string[]) });
            if (msbuildExecuteMethod == null)
            {
                Console.Error.WriteLine($"Failed to locate Execute method in {MSBuildAppTypeName}!");
                return 1002;
            }

            // Put the path to the msbuild exe in the args list (it expects this to be there)
            var newArgs = new string[msbuildArgs.Length + 1];
            newArgs[0] = msbuildPath;
            Array.Copy(msbuildArgs, 0, newArgs, 1, msbuildArgs.Length);

            var result = (int)msbuildExecuteMethod.Invoke(null, new[] { newArgs });
            return result;
        }
    }
}
