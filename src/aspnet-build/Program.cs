using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Runtime.Loader;

namespace aspnet_build
{
    public class Program
    {
        private static readonly string MSBuildAppTypeName = "Microsoft.Build.CommandLine.MSBuildApp";

        public static int Main(string[] args)
        {
            var msbuildPath = Path.Combine(AppContext.BaseDirectory, "runtimes", "any", "native", "MSBuild.exe");
            if (!File.Exists(msbuildPath))
            {
                Console.Error.WriteLine($"Unable to locate MSBuild in: {msbuildPath}");
                Console.Error.WriteLine("aspnet-build must be published with 'dotnet publish' to execute correctly");
                return 1000;
            }

            // Override the MSBUILD_EXE_PATH environment variable used to locate itself
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

            // Process arguments
            args = ProcessArguments(args).ToArray();

            // Put the path to the msbuild exe in the args list (it expects this to be there)
            var newArgs = new string[args.Length + 1];
            newArgs[0] = msbuildPath;
            Array.Copy(args, 0, newArgs, 1, args.Length);

            var result = (int)msbuildExecuteMethod.Invoke(null, new[] { newArgs });
            return result;
        }

        private static IEnumerable<string> ProcessArguments(string[] args)
        {
            foreach (var arg in args)
            {
                if (arg.StartsWith("/repo:"))
                {
                    var repo = arg.Substring(6).Trim('"', '\'');
                    Directory.SetCurrentDirectory(repo);
                    var makefile = Path.Combine(repo, "makefile.proj");
                    if (File.Exists(makefile))
                    {
                        yield return Path.Combine(repo, "makefile.proj");
                    }
                    else
                    {
                        yield return Path.Combine(AppContext.BaseDirectory, "msbuild", "DefaultMakefile.proj");
                    }
                }
                else
                {
                    yield return arg;
                }
            }

            yield return $"/p:AspNetBuildDirectory=\"{AppContext.BaseDirectory}\"";
        }
    }
}
